package database

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/rs/zerolog/log"
)

// PoolOptions controls the tunables for the pgx pool. Zero values fall back
// to sensible defaults.
type PoolOptions struct {
	MaxConns        int32
	MinConns        int32
	MaxConnIdleTime time.Duration
	MaxConnLifetime time.Duration
	// StatementTimeout (ms) — passed to Postgres via `statement_timeout` runtime param.
	StatementTimeoutMS int
	// IdleInTransactionTimeout (ms) — passed via `idle_in_transaction_session_timeout`.
	IdleInTransactionTimeoutMS int
}

func defaultedPoolOptions(opts PoolOptions) PoolOptions {
	if opts.MaxConns <= 0 {
		opts.MaxConns = 20
	}
	if opts.MinConns < 0 {
		opts.MinConns = 0
	}
	if opts.MinConns == 0 {
		opts.MinConns = 2
	}
	if opts.MaxConnIdleTime <= 0 {
		opts.MaxConnIdleTime = 5 * time.Minute
	}
	if opts.MaxConnLifetime <= 0 {
		opts.MaxConnLifetime = 30 * time.Minute
	}
	if opts.StatementTimeoutMS <= 0 {
		opts.StatementTimeoutMS = 30000
	}
	if opts.IdleInTransactionTimeoutMS <= 0 {
		opts.IdleInTransactionTimeoutMS = 60000
	}
	return opts
}

func NewPostgres(ctx context.Context, databaseURL string, opts PoolOptions) (*pgxpool.Pool, error) {
	opts = defaultedPoolOptions(opts)
	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse postgres dsn: %w", err)
	}
	cfg.MaxConns = opts.MaxConns
	cfg.MinConns = opts.MinConns
	cfg.MaxConnIdleTime = opts.MaxConnIdleTime
	cfg.MaxConnLifetime = opts.MaxConnLifetime
	if cfg.ConnConfig.RuntimeParams == nil {
		cfg.ConnConfig.RuntimeParams = make(map[string]string)
	}
	cfg.ConnConfig.RuntimeParams["statement_timeout"] = fmt.Sprintf("%d", opts.StatementTimeoutMS)
	cfg.ConnConfig.RuntimeParams["idle_in_transaction_session_timeout"] = fmt.Sprintf("%d", opts.IdleInTransactionTimeoutMS)

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("connect postgres: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}
	return pool, nil
}

// RunMigrations applies every `*.sql` file under migrationsDir whose filename
// hasn't already been recorded in the schema_migrations table. Each file is
// applied inside its own transaction; the version (filename) is inserted on
// success. Files are sorted lexicographically so the numeric prefix
// (`001_`, `002_`, ...) determines order.
//
// A migration may opt out of the surrounding transaction by including the
// directive `-- @notx` in its leading comment block. This is required for
// statements like `ALTER TYPE ... ADD VALUE` that Postgres refuses to run
// inside a transaction. Files that opt out lose atomicity, so they should
// only contain idempotent `IF NOT EXISTS` / `IF EXISTS` statements.
func RunMigrations(ctx context.Context, pool *pgxpool.Pool, migrationsDir string) error {
	if _, err := pool.Exec(ctx, `
		CREATE TABLE IF NOT EXISTS schema_migrations (
			version    TEXT PRIMARY KEY,
			applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)`); err != nil {
		return fmt.Errorf("create schema_migrations: %w", err)
	}

	entries, err := os.ReadDir(migrationsDir)
	if err != nil {
		return fmt.Errorf("read migrations dir %s: %w", migrationsDir, err)
	}
	var files []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		if !strings.HasSuffix(strings.ToLower(name), ".sql") {
			continue
		}
		files = append(files, name)
	}
	sort.Strings(files)

	for _, name := range files {
		applied, err := migrationApplied(ctx, pool, name)
		if err != nil {
			return err
		}
		if applied {
			continue
		}
		path := filepath.Join(migrationsDir, name)
		sqlBytes, err := os.ReadFile(path)
		if err != nil {
			return fmt.Errorf("read migration %s: %w", name, err)
		}
		sqlText := string(sqlBytes)
		if hasNoTxDirective(sqlText) {
			if err := applyMigrationNoTx(ctx, pool, name, sqlText); err != nil {
				return err
			}
		} else {
			if err := applyMigration(ctx, pool, name, sqlText); err != nil {
				return err
			}
		}
		log.Info().Str("migration", name).Msg("applied")
	}
	return nil
}

// hasNoTxDirective scans the leading comment block of a migration file for
// `@notx`. We only honor the directive in leading `--` comment lines so that
// stray occurrences inside actual statements can't accidentally disable the
// transaction wrapper.
func hasNoTxDirective(sqlText string) bool {
	for _, raw := range strings.Split(sqlText, "\n") {
		line := strings.TrimSpace(raw)
		if line == "" {
			continue
		}
		if !strings.HasPrefix(line, "--") {
			return false
		}
		if strings.Contains(line, "@notx") {
			return true
		}
	}
	return false
}

func migrationApplied(ctx context.Context, pool *pgxpool.Pool, version string) (bool, error) {
	var exists bool
	err := pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = $1)`, version,
	).Scan(&exists)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return false, fmt.Errorf("check migration %s: %w", version, err)
	}
	return exists, nil
}

func applyMigration(ctx context.Context, pool *pgxpool.Pool, version, sqlText string) error {
	tx, err := pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("begin tx for %s: %w", version, err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if _, err := tx.Exec(ctx, sqlText); err != nil {
		return fmt.Errorf("apply %s: %w", version, err)
	}
	if _, err := tx.Exec(ctx,
		`INSERT INTO schema_migrations (version) VALUES ($1) ON CONFLICT DO NOTHING`,
		version,
	); err != nil {
		return fmt.Errorf("record %s: %w", version, err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit %s: %w", version, err)
	}
	return nil
}

// applyMigrationNoTx executes a migration in autocommit mode. Statements like
// `ALTER TYPE ... ADD VALUE` require this since Postgres refuses them inside
// a transaction block. The schema_migrations row is recorded only on success;
// partial application is possible here, so the migration MUST be idempotent.
func applyMigrationNoTx(ctx context.Context, pool *pgxpool.Pool, version, sqlText string) error {
	if _, err := pool.Exec(ctx, sqlText); err != nil {
		return fmt.Errorf("apply %s (no-tx): %w", version, err)
	}
	if _, err := pool.Exec(ctx,
		`INSERT INTO schema_migrations (version) VALUES ($1) ON CONFLICT DO NOTHING`,
		version,
	); err != nil {
		return fmt.Errorf("record %s: %w", version, err)
	}
	return nil
}
