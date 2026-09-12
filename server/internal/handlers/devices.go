package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/telegramclone/server/internal/httperr"
	"github.com/telegramclone/server/internal/middleware"
	"github.com/telegramclone/server/internal/services"
	"github.com/telegramclone/server/internal/utils"
)

type DeviceHandler struct {
	users *services.UserService
}

func NewDeviceHandler(users *services.UserService) *DeviceHandler {
	return &DeviceHandler{users: users}
}

type pushTokenReq struct {
	Token    string `json:"token" validate:"required"`
	Platform string `json:"platform" validate:"required,oneof=ios android web fcm"`
}

func (h *DeviceHandler) SavePushToken(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	var req pushTokenReq
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}
	if err := h.users.SavePushToken(c.Context(), userID, req.Token, req.Platform); err != nil {
		return httperr.Internal(c, err)
	}
	return utils.OK(c, fiber.Map{"saved": true})
}
