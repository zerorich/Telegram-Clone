package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/telegramclone/server/internal/models"
	"github.com/telegramclone/server/internal/utils"
)

type OTPRepository struct {
	pool *pgxpool.Pool
}

func NewOTPRepository(pool *pgxpool.Pool) *OTPRepository {
	return &OTPRepository{pool: pool}
}

func (r *OTPRepository) Create(ctx context.Context, email, codeHash string, expiresAt time.Time) (*models.OTPCode, error) {
	var otp models.OTPCode
	err := r.pool.QueryRow(ctx, `
		INSERT INTO otp_codes (email, code, expires_at)
		VALUES ($1, $2, $3)
		RETURNING id, email, code, expires_at, used`,
		email, codeHash, expiresAt,
	).Scan(&otp.ID, &otp.Email, &otp.Code, &otp.ExpiresAt, &otp.Used)
	return &otp, err
}

// Verify marks the first matching unused, unexpired OTP as used after comparing
// the provided plaintext code against stored hashes in Go (constant-time).
func (r *OTPRepository) Verify(ctx context.Context, email, code, pepper string) (bool, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, code FROM otp_codes
		WHERE email = $1 AND used = FALSE AND expires_at > NOW()
		ORDER BY created_at DESC`,
		email,
	)
	if err != nil {
		return false, err
	}
	defer rows.Close()

	var matchedID uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		var storedHash string
		if err := rows.Scan(&id, &storedHash); err != nil {
			return false, err
		}
		if utils.CompareOTP(code, pepper, storedHash) {
			matchedID = id
			break
		}
	}
	if err := rows.Err(); err != nil {
		return false, err
	}
	if matchedID == uuid.Nil {
		return false, nil
	}

	tag, err := r.pool.Exec(ctx, `
		UPDATE otp_codes SET used = TRUE
		WHERE id = $1 AND used = FALSE AND expires_at > NOW()`,
		matchedID,
	)
	if err != nil {
		return false, err
	}
	if tag.RowsAffected() == 0 {
		return false, nil
	}
	return true, nil
}

func (r *OTPRepository) InvalidateOld(ctx context.Context, email string) error {
	_, err := r.pool.Exec(ctx, `UPDATE otp_codes SET used = TRUE WHERE email = $1 AND used = FALSE`, email)
	return err
}
