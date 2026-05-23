package middleware

import (
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/repository"
	"github.com/telegramclone/server/internal/utils"
)

const UserIDKey = "userID"

// JWTAuth validates an access JWT and, when a Redis-backed AuthRedisRepository
// is provided, also checks the per-jti blacklist set by Logout. Tokens without
// a jti (legacy) bypass the blacklist check for backward compatibility.
//
// In addition to the standard `Authorization: Bearer <token>` header, this
// middleware also accepts `?t=<token>` as a fallback. The query-string form
// is necessary for browser <img>/<video> elements which can't attach custom
// headers; it's only honored when no Authorization header is present so the
// header path remains the canonical one.
func JWTAuth(jwtManager *utils.JWTManager, authRedis *repository.AuthRedisRepository) fiber.Handler {
	return func(c *fiber.Ctx) error {
		var rawToken string
		if header := c.Get("Authorization"); header != "" {
			parts := strings.SplitN(header, " ", 2)
			if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
				return utils.Fail(c, fiber.StatusUnauthorized, "invalid authorization header")
			}
			rawToken = strings.TrimSpace(parts[1])
		} else if q := c.Query("t"); q != "" {
			rawToken = q
		} else {
			return utils.Fail(c, fiber.StatusUnauthorized, "missing authorization header")
		}
		claims, err := jwtManager.ParseToken(rawToken)
		if err != nil || claims.TokenType != utils.TokenTypeAccess {
			return utils.Fail(c, fiber.StatusUnauthorized, "invalid or expired token")
		}
		if authRedis != nil && claims.ID != "" {
			revoked, err := authRedis.IsAccessTokenRevoked(c.Context(), claims.ID)
			if err == nil && revoked {
				return utils.Fail(c, fiber.StatusUnauthorized, "token revoked")
			}
		}
		c.Locals(UserIDKey, claims.UserID)
		return c.Next()
	}
}

func GetUserID(c *fiber.Ctx) (uuid.UUID, error) {
	v := c.Locals(UserIDKey)
	if v == nil {
		return uuid.Nil, fiber.ErrUnauthorized
	}
	id, ok := v.(uuid.UUID)
	if !ok {
		return uuid.Nil, fiber.ErrUnauthorized
	}
	return id, nil
}

// GetBearerToken extracts the raw token from `Authorization: Bearer <token>`.
// Returns empty string when missing or malformed.
func GetBearerToken(c *fiber.Ctx) string {
	header := c.Get("Authorization")
	if header == "" {
		return ""
	}
	parts := strings.SplitN(header, " ", 2)
	if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
		return ""
	}
	return strings.TrimSpace(parts[1])
}
