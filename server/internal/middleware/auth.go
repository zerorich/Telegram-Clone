package middleware

import (
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/utils"
)

const UserIDKey = "userID"

func JWTAuth(jwtManager *utils.JWTManager) fiber.Handler {
	return func(c *fiber.Ctx) error {
		header := c.Get("Authorization")
		if header == "" {
			return utils.Fail(c, fiber.StatusUnauthorized, "missing authorization header")
		}
		parts := strings.SplitN(header, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "bearer") {
			return utils.Fail(c, fiber.StatusUnauthorized, "invalid authorization header")
		}
		claims, err := jwtManager.ParseToken(parts[1])
		if err != nil || claims.TokenType != utils.TokenTypeAccess {
			return utils.Fail(c, fiber.StatusUnauthorized, "invalid or expired token")
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
