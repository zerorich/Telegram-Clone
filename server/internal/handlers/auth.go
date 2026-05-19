package handlers

import (
	"errors"

	"github.com/gofiber/fiber/v2"
	"github.com/telegramclone/server/internal/middleware"
	"github.com/telegramclone/server/internal/services"
	"github.com/telegramclone/server/internal/utils"
)

type AuthHandler struct {
	auth *services.AuthService
}

func NewAuthHandler(auth *services.AuthService) *AuthHandler {
	return &AuthHandler{auth: auth}
}

type sendCodeReq struct {
	Email string `json:"email" validate:"required,email"`
}

type verifyCodeReq struct {
	Email string `json:"email" validate:"required,email"`
	Code  string `json:"code" validate:"required,len=6"`
}

type completeProfileReq struct {
	Email   string  `json:"email" validate:"required,email"`
	Name    string  `json:"name" validate:"required"`
	Surname *string `json:"surname"`
	Phone   string  `json:"phone"`
}

type refreshReq struct {
	RefreshToken string `json:"refresh_token" validate:"required"`
}

func (h *AuthHandler) SendCode(c *fiber.Ctx) error {
	var req sendCodeReq
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}
	if err := h.auth.SendCode(c.Context(), req.Email); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.OK(c, fiber.Map{"message": "OTP sent to email"})
}

func (h *AuthHandler) VerifyCode(c *fiber.Ctx) error {
	var req verifyCodeReq
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}
	result, err := h.auth.VerifyCode(c.Context(), req.Email, req.Code)
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	if result.IsNewUser {
		return utils.OK(c, fiber.Map{
			"is_new_user": true,
			"verified":    true,
		})
	}
	result.User.PasswordHash = ""
	return utils.OK(c, fiber.Map{
		"is_new_user": false,
		"user":        result.User,
		"tokens":      result.Tokens,
	})
}

func (h *AuthHandler) CompleteProfile(c *fiber.Ctx) error {
	var req completeProfileReq
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}
	user, tokens, err := h.auth.CompleteProfile(c.Context(), req.Email, req.Name, req.Phone, req.Surname)
	if err != nil {
		if errors.Is(err, services.ErrNotVerified) {
			return utils.Fail(c, fiber.StatusBadRequest, err.Error())
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	user.PasswordHash = ""
	return utils.OK(c, fiber.Map{"user": user, "tokens": tokens})
}

func (h *AuthHandler) Refresh(c *fiber.Ctx) error {
	var req refreshReq
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}
	tokens, err := h.auth.Refresh(c.Context(), req.RefreshToken)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, err.Error())
	}
	return utils.OK(c, tokens)
}

func (h *AuthHandler) Logout(c *fiber.Ctx) error {
	var req refreshReq
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}
	_ = h.auth.Logout(c.Context(), req.RefreshToken)
	return utils.OK(c, fiber.Map{"message": "logged out"})
}
