package database

import (
	"context"
	"crypto/tls"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisOptions narrows go-redis.Options to the knobs the rest of the app
// needs to set; everything else uses sensible defaults appropriate for a
// modestly-loaded backend.
type RedisOptions struct {
	Addr     string
	Password string
	DB       int
	UseTLS   bool
}

func NewRedis(ctx context.Context, opts RedisOptions) (*redis.Client, error) {
	options := &redis.Options{
		Addr:         opts.Addr,
		Password:     opts.Password,
		DB:           opts.DB,
		DialTimeout:  5 * time.Second,
		ReadTimeout:  3 * time.Second,
		WriteTimeout: 3 * time.Second,
		PoolSize:     20,
		MinIdleConns: 2,
	}
	if opts.UseTLS {
		// Minimal TLS config; rely on the system CA pool for verification.
		options.TLSConfig = &tls.Config{MinVersion: tls.VersionTLS12}
	}
	client := redis.NewClient(options)
	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("ping redis: %w", err)
	}
	return client, nil
}
