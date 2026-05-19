package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/middleware"
	"github.com/telegramclone/server/internal/services"
	"github.com/telegramclone/server/internal/utils"
)

type UserHandler struct {
	users *services.UserService
}

func NewUserHandler(users *services.UserService) *UserHandler {
	return &UserHandler{users: users}
}

type updateMeReq struct {
	Name     string  `json:"name" validate:"required"`
	Surname  *string `json:"surname"`
	Username *string `json:"username"`
}

func (h *UserHandler) GetMe(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	user, err := h.users.GetMe(c.Context(), userID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.OK(c, h.users.SanitizeUser(user))
}

func (h *UserHandler) UpdateMe(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	var req updateMeReq
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}
	user, err := h.users.UpdateMe(c.Context(), userID, req.Name, req.Surname, req.Username)
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, h.users.SanitizeUser(user))
}

func (h *UserHandler) UploadAvatar(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	file, err := c.FormFile("avatar")
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "avatar file required")
	}
	f, err := file.Open()
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	defer f.Close()
	data, err := utils.ReadAllLimited(f, 5<<20)
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	user, err := h.users.UploadAvatar(c.Context(), userID, data)
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, h.users.SanitizeUser(user))
}

func (h *UserHandler) GetByID(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid user id")
	}
	user, err := h.users.GetByID(c.Context(), id)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, err.Error())
	}
	if user == nil {
		return utils.Fail(c, fiber.StatusNotFound, "user not found")
	}
	return utils.OK(c, h.users.SanitizeUser(user))
}

func (h *UserHandler) Search(c *fiber.Ctx) error {
	q := c.Query("q")
	if q == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "query parameter q is required")
	}
	users, err := h.users.Search(c.Context(), q)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, err.Error())
	}
	for i := range users {
		users[i].PasswordHash = ""
	}
	return utils.OK(c, users)
}
