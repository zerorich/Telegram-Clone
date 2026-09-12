package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

const (
	keyRefreshPrefix       = "refresh:"
	keyRegisterPrefix      = "register:"
	keyVerifiedPrefix      = "verified:"
	keyRevokedAccessPrefix = "revoked_access:"
	keyOTPFailPrefix       = "otp_fail:"
	keyOTPLockPrefix       = "otp_lock:"
)

type AuthRedisRepository struct {
	rdb *redis.Client
}

func NewAuthRedisRepository(rdb *redis.Client) *AuthRedisRepository {
	return &AuthRedisRepository{rdb: rdb}
}

func (r *AuthRedisRepository) StoreRefreshToken(ctx context.Context, userID uuid.UUID, jti string, ttl time.Duration) error {
	key := fmt.Sprintf("%s%s:%s", keyRefreshPrefix, userID.String(), jti)
	return r.rdb.Set(ctx, key, "1", ttl).Err()
}

func (r *AuthRedisRepository) ValidateRefreshToken(ctx context.Context, userID uuid.UUID, jti string) (bool, error) {
	key := fmt.Sprintf("%s%s:%s", keyRefreshPrefix, userID.String(), jti)
	n, err := r.rdb.Exists(ctx, key).Result()
	return n > 0, err
}

func (r *AuthRedisRepository) RevokeRefreshToken(ctx context.Context, userID uuid.UUID, jti string) error {
	key := fmt.Sprintf("%s%s:%s", keyRefreshPrefix, userID.String(), jti)
	return r.rdb.Del(ctx, key).Err()
}

func (r *AuthRedisRepository) RevokeAllRefreshTokens(ctx context.Context, userID uuid.UUID) error {
	pattern := fmt.Sprintf("%s%s:*", keyRefreshPrefix, userID.String())
	iter := r.rdb.Scan(ctx, 0, pattern, 100).Iterator()
	for iter.Next(ctx) {
		if err := r.rdb.Del(ctx, iter.Val()).Err(); err != nil {
			return err
		}
	}
	return iter.Err()
}

func (r *AuthRedisRepository) StoreRegistration(ctx context.Context, email, phone string, ttl time.Duration) error {
	key := keyRegisterPrefix + email
	return r.rdb.Set(ctx, key, phone, ttl).Err()
}

func (r *AuthRedisRepository) GetRegistrationPhone(ctx context.Context, email string) (string, error) {
	return r.rdb.Get(ctx, keyRegisterPrefix+email).Result()
}

func (r *AuthRedisRepository) MarkEmailVerified(ctx context.Context, email string, ttl time.Duration) error {
	return r.rdb.Set(ctx, keyVerifiedPrefix+email, "1", ttl).Err()
}

func (r *AuthRedisRepository) IsEmailVerified(ctx context.Context, email string) (bool, error) {
	n, err := r.rdb.Exists(ctx, keyVerifiedPrefix+email).Result()
	return n > 0, err
}

// RevokeAccessToken stores the access-token jti for the remainder of its
// natural lifetime, after which Redis will expire the entry automatically.
func (r *AuthRedisRepository) RevokeAccessToken(ctx context.Context, jti string, ttl time.Duration) error {
	if jti == "" || ttl <= 0 {
		return nil
	}
	return r.rdb.Set(ctx, keyRevokedAccessPrefix+jti, "1", ttl).Err()
}

func (r *AuthRedisRepository) IsAccessTokenRevoked(ctx context.Context, jti string) (bool, error) {
	if jti == "" {
		return false, nil
	}
	n, err := r.rdb.Exists(ctx, keyRevokedAccessPrefix+jti).Result()
	return n > 0, err
}

func (r *AuthRedisRepository) ClearRegistration(ctx context.Context, email string) error {
	pipe := r.rdb.Pipeline()
	pipe.Del(ctx, keyRegisterPrefix+email)
	pipe.Del(ctx, keyVerifiedPrefix+email)
	_, err := pipe.Exec(ctx)
	return err
}

func (r *AuthRedisRepository) IsOTPLocked(ctx context.Context, email string) (bool, error) {
	n, err := r.rdb.Exists(ctx, keyOTPLockPrefix+email).Result()
	return n > 0, err
}

func (r *AuthRedisRepository) RecordOTPFailure(ctx context.Context, email string, maxAttempts int, lockout time.Duration) error {
	failKey := keyOTPFailPrefix + email
	n, err := r.rdb.Incr(ctx, failKey).Result()
	if err != nil {
		return err
	}
	if n == 1 {
		_ = r.rdb.Expire(ctx, failKey, lockout).Err()
	}
	if int(n) >= maxAttempts {
		pipe := r.rdb.Pipeline()
		pipe.Set(ctx, keyOTPLockPrefix+email, "1", lockout)
		pipe.Del(ctx, failKey)
		_, err = pipe.Exec(ctx)
	}
	return err
}

func (r *AuthRedisRepository) ClearOTPFailures(ctx context.Context, email string) error {
	pipe := r.rdb.Pipeline()
	pipe.Del(ctx, keyOTPFailPrefix+email)
	pipe.Del(ctx, keyOTPLockPrefix+email)
	_, err := pipe.Exec(ctx)
	return err
}
