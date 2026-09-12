package repository

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/telegramclone/server/internal/models"
)

type UserRepository struct {
	pool *pgxpool.Pool
}

func NewUserRepository(pool *pgxpool.Pool) *UserRepository {
	return &UserRepository{pool: pool}
}

func scanUser(row pgx.Row) (*models.User, error) {
	var u models.User
	err := row.Scan(
		&u.ID, &u.Phone, &u.Email, &u.PasswordHash,
		&u.Name, &u.Surname, &u.Username, &u.AvatarURL,
		&u.IsVerified, &u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

const userColumns = `id, phone, email, password_hash, name, surname, username, avatar_url, is_verified, created_at, updated_at`

func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+userColumns+` FROM users WHERE id = $1`, id)
	u, err := scanUser(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return u, err
}

func (r *UserRepository) GetByPhone(ctx context.Context, phone string) (*models.User, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+userColumns+` FROM users WHERE phone = $1`, phone)
	u, err := scanUser(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return u, err
}

func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*models.User, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+userColumns+` FROM users WHERE email = $1`, email)
	u, err := scanUser(row)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return u, err
}

func (r *UserRepository) ExistsByPhoneOrEmail(ctx context.Context, phone, email string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM users WHERE phone = $1 OR email = $2)`,
		phone, email,
	).Scan(&exists)
	return exists, err
}

func (r *UserRepository) Create(ctx context.Context, u *models.User) error {
	row := r.pool.QueryRow(ctx, `
		INSERT INTO users (phone, email, password_hash, name, surname, username, avatar_url, is_verified)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING `+userColumns,
		u.Phone, u.Email, u.PasswordHash, u.Name, u.Surname, u.Username, u.AvatarURL, u.IsVerified,
	)
	created, err := scanUser(row)
	if err != nil {
		return err
	}
	*u = *created
	return nil
}

func (r *UserRepository) Update(ctx context.Context, id uuid.UUID, name string, surname *string, username *string) (*models.User, error) {
	row := r.pool.QueryRow(ctx, `
		UPDATE users SET name = $2, surname = $3, username = $4, updated_at = NOW()
		WHERE id = $1
		RETURNING `+userColumns,
		id, name, surname, username,
	)
	return scanUser(row)
}

func (r *UserRepository) UpdateAvatar(ctx context.Context, id uuid.UUID, avatarURL string) (*models.User, error) {
	row := r.pool.QueryRow(ctx, `
		UPDATE users SET avatar_url = $2, updated_at = NOW()
		WHERE id = $1
		RETURNING `+userColumns,
		id, avatarURL,
	)
	return scanUser(row)
}

func (r *UserRepository) Search(ctx context.Context, query string, limit int) ([]models.User, error) {
	q := "%" + strings.ToLower(query) + "%"
	rows, err := r.pool.Query(ctx, `
		SELECT `+userColumns+` FROM users
		WHERE LOWER(username) LIKE $1 OR phone LIKE $2
		ORDER BY name
		LIMIT $3`,
		q, "%"+query+"%", limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []models.User
	for rows.Next() {
		var u models.User
		if err := rows.Scan(
			&u.ID, &u.Phone, &u.Email, &u.PasswordHash,
			&u.Name, &u.Surname, &u.Username, &u.AvatarURL,
			&u.IsVerified, &u.CreatedAt, &u.UpdatedAt,
		); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	return users, rows.Err()
}

func (r *UserRepository) UsernameTaken(ctx context.Context, username string, excludeID uuid.UUID) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM users WHERE username = $1 AND id != $2)`,
		username, excludeID,
	).Scan(&exists)
	return exists, err
}

func (r *UserRepository) GetByIDs(ctx context.Context, ids []uuid.UUID) (map[uuid.UUID]*models.User, error) {
	if len(ids) == 0 {
		return map[uuid.UUID]*models.User{}, nil
	}
	rows, err := r.pool.Query(ctx, `SELECT `+userColumns+` FROM users WHERE id = ANY($1)`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make(map[uuid.UUID]*models.User)
	for rows.Next() {
		var u models.User
		if err := rows.Scan(
			&u.ID, &u.Phone, &u.Email, &u.PasswordHash,
			&u.Name, &u.Surname, &u.Username, &u.AvatarURL,
			&u.IsVerified, &u.CreatedAt, &u.UpdatedAt,
		); err != nil {
			return nil, err
		}
		result[u.ID] = &u
	}
	return result, rows.Err()
}

func (r *UserRepository) UpdatePushToken(ctx context.Context, id uuid.UUID, token, platform string) error {
	_, err := r.pool.Exec(ctx, `
		UPDATE users SET push_token = $2, push_platform = $3, updated_at = NOW()
		WHERE id = $1`,
		id, token, platform,
	)
	return err
}

type PushDevice struct {
	UserID   uuid.UUID
	Token    string
	Platform string
}

func (r *UserRepository) ListPushTokens(ctx context.Context, ids []uuid.UUID) ([]PushDevice, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, push_token, COALESCE(push_platform, '')
		FROM users
		WHERE id = ANY($1) AND push_token IS NOT NULL AND BTRIM(push_token) <> ''`,
		ids,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var devices []PushDevice
	for rows.Next() {
		var d PushDevice
		if err := rows.Scan(&d.UserID, &d.Token, &d.Platform); err != nil {
			return nil, err
		}
		devices = append(devices, d)
	}
	return devices, rows.Err()
}

func (r *UserRepository) ValidateIDsExist(ctx context.Context, ids []uuid.UUID) error {
	var count int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM users WHERE id = ANY($1)`, ids).Scan(&count)
	if err != nil {
		return err
	}
	if count != len(ids) {
		return fmt.Errorf("one or more users not found")
	}
	return nil
}
