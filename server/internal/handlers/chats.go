package handlers

import (
	"encoding/json"
	"errors"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/middleware"
	"github.com/telegramclone/server/internal/services"
	"github.com/telegramclone/server/internal/utils"
)

type ChatHandler struct {
	chats *services.ChatService
}

func NewChatHandler(chats *services.ChatService) *ChatHandler {
	return &ChatHandler{chats: chats}
}

type directChatReq struct {
	UserID uuid.UUID `json:"user_id" validate:"required"`
}

type groupChatReq struct {
	Name      string      `json:"name" validate:"required"`
	MemberIDs []uuid.UUID `json:"member_ids" validate:"required,min=1"`
}

type updateGroupReq struct {
	Name string `json:"name"`
}

type addMembersReq struct {
	MemberIDs []uuid.UUID `json:"member_ids" validate:"required,min=1"`
}

func (h *ChatHandler) List(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chats, err := h.chats.List(c.Context(), userID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, err.Error())
	}
	if chats == nil {
		return utils.OK(c, []any{})
	}
	return utils.OK(c, chats)
}

func (h *ChatHandler) CreateDirect(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	var req directChatReq
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}
	chat, err := h.chats.CreateDirect(c.Context(), userID, req.UserID)
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	_, members, err := h.chats.Get(c.Context(), chat.ID, userID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.OK(c, fiber.Map{
		"id":         chat.ID,
		"type":       chat.Type,
		"name":       chat.Name,
		"avatar_url": chat.AvatarURL,
		"created_by": chat.CreatedBy,
		"created_at": chat.CreatedAt,
		"members":    members,
	})
}

func (h *ChatHandler) CreateGroup(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}

	var name string
	var memberIDs []uuid.UUID
	var avatarData []byte

	contentType := c.Get("Content-Type")
	if strings.Contains(contentType, "multipart/form-data") {
		name = c.FormValue("name")
		if idsJSON := c.FormValue("member_ids"); idsJSON != "" {
			_ = json.Unmarshal([]byte(idsJSON), &memberIDs)
		}
		if file, err := c.FormFile("avatar"); err == nil {
			f, err := file.Open()
			if err == nil {
				defer f.Close()
				avatarData, _ = utils.ReadAllLimited(f, 5<<20)
			}
		}
	} else {
		var req groupChatReq
		if err := middleware.ValidateBody(c, &req); err != nil {
			return err
		}
		name = req.Name
		memberIDs = req.MemberIDs
	}

	if name == "" || len(memberIDs) == 0 {
		return utils.Fail(c, fiber.StatusBadRequest, "name and member_ids are required")
	}

	chat, err := h.chats.CreateGroup(c.Context(), userID, name, memberIDs, avatarData)
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, chat)
}

func (h *ChatHandler) Get(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	chat, members, err := h.chats.Get(c.Context(), chatID, userID)
	if err != nil {
		if errors.Is(err, services.ErrNotMember) {
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		}
		if errors.Is(err, services.ErrChatNotFound) {
			return utils.Fail(c, fiber.StatusNotFound, err.Error())
		}
		return utils.Fail(c, fiber.StatusInternalServerError, err.Error())
	}
	h.chats.SanitizeMembers(members)
	return utils.OK(c, fiber.Map{"chat": chat, "members": members})
}

func (h *ChatHandler) Update(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}

	var name *string
	var avatarData []byte

	contentType := c.Get("Content-Type")
	if strings.Contains(contentType, "multipart/form-data") {
		if n := c.FormValue("name"); n != "" {
			name = &n
		}
		if file, err := c.FormFile("avatar"); err == nil {
			f, err := file.Open()
			if err == nil {
				defer f.Close()
				avatarData, _ = utils.ReadAllLimited(f, 5<<20)
			}
		}
	} else {
		var req updateGroupReq
		if err := c.BodyParser(&req); err != nil {
			return utils.Fail(c, fiber.StatusBadRequest, "invalid request body")
		}
		if req.Name != "" {
			name = &req.Name
		}
	}

	chat, err := h.chats.UpdateGroup(c.Context(), chatID, userID, name, nil, avatarData)
	if err != nil {
		if errors.Is(err, services.ErrForbidden) {
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, chat)
}

func (h *ChatHandler) AddMembers(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	var req addMembersReq
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}
	if err := h.chats.AddMembers(c.Context(), chatID, userID, req.MemberIDs); err != nil {
		if errors.Is(err, services.ErrForbidden) {
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, fiber.Map{"added": true})
}

func (h *ChatHandler) RemoveMember(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	targetID, err := uuid.Parse(c.Params("userId"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid user id")
	}
	if err := h.chats.RemoveMember(c.Context(), chatID, userID, targetID); err != nil {
		if errors.Is(err, services.ErrForbidden) {
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, fiber.Map{"removed": true})
}

func (h *ChatHandler) Leave(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	if err := h.chats.Leave(c.Context(), chatID, userID); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, fiber.Map{"left": true})
}
