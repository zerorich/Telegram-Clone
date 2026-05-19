package repository

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/telegramclone/server/internal/models"
)

type OTPRepository struct {
	pool *pgxpool.Pool
}

func NewOTPRepository(pool *pgxpool.Pool) *OTPRepository {
	return &OTPRepository{pool: pool}
}

func (r *OTPRepository) Create(ctx context.Context, email, code string, expiresAt time.Time) (*models.OTPCode, error) {
	var otp models.OTPCode
	err := r.pool.QueryRow(ctx, `
		INSERT INTO otp_codes (email, code, expires_at)
		VALUES ($1, $2, $3)
		RETURNING id, email, code, expires_at, used`,
		email, code, expiresAt,
	).Scan(&otp.ID, &otp.Email, &otp.Code, &otp.ExpiresAt, &otp.Used)
	return &otp, err
}

func (r *OTPRepository) Verify(ctx context.Context, email, code string) (bool, error) {
	var id uuid.UUID
	err := r.pool.QueryRow(ctx, `
		UPDATE otp_codes SET used = TRUE
		WHERE email = $1 AND code = $2 AND used = FALSE AND expires_at > NOW()
		RETURNING id`,
		email, code,
	).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (r *OTPRepository) InvalidateOld(ctx context.Context, email string) error {
	_, err := r.pool.Exec(ctx, `UPDATE otp_codes SET used = TRUE WHERE email = $1 AND used = FALSE`, email)
	return err
}
