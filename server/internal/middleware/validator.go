package middleware

import (
	"github.com/go-playground/validator/v10"
	"github.com/gofiber/fiber/v2"
	"github.com/telegramclone/server/internal/utils"
)

var validate = validator.New()

func ValidateBody(c *fiber.Ctx, dest interface{}) error {
	if err := c.BodyParser(dest); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid request body")
	}
	if err := validate.Struct(dest); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return nil
}
