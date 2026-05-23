package handlers

import (
	"errors"
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/middleware"
	"github.com/telegramclone/server/internal/models"
	"github.com/telegramclone/server/internal/services"
	"github.com/telegramclone/server/internal/utils"
)

type MessageHandler struct {
	messages *services.MessageService
}

func NewMessageHandler(messages *services.MessageService) *MessageHandler {
	return &MessageHandler{messages: messages}
}

type sendTextReq struct {
	Content   string     `json:"content" validate:"required"`
	ReplyToID *uuid.UUID `json:"reply_to_id"`
}

type markReadReq struct {
	MessageID uuid.UUID `json:"message_id" validate:"required"`
}

type editMessageReq struct {
	Content string `json:"content" validate:"required"`
}

func (h *MessageHandler) List(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	cursor, err := utils.DecodeCursor(c.Query("cursor"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	limit := c.QueryInt("limit", 50)
	msgs, next, err := h.messages.List(c.Context(), chatID, userID, cursor, limit)
	if err != nil {
		if errors.Is(err, services.ErrNotMember) {
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		}
		return utils.Fail(c, fiber.StatusInternalServerError, err.Error())
	}
	return utils.OK(c, fiber.Map{
		"messages":    msgs,
		"next_cursor": utils.EncodeCursor(next),
	})
}

func (h *MessageHandler) SendText(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	var req sendTextReq
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}
	msg, err := h.messages.SendText(c.Context(), chatID, userID, req.Content, req.ReplyToID)
	if err != nil {
		if errors.Is(err, services.ErrNotMember) {
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, msg)
}

func (h *MessageHandler) SendMedia(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	msgType := models.MessageType(c.FormValue("type"))
	if msgType == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "type is required")
	}
	file, err := c.FormFile("file")
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "file is required")
	}
	f, err := file.Open()
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	defer f.Close()

	maxSize := int64(50 << 20)
	switch msgType {
	case models.MessageTypeImage:
		maxSize = 20 << 20
	case models.MessageTypeVideo:
		maxSize = 100 << 20
	case models.MessageTypeVoice:
		maxSize = 10 << 20
	}
	data, err := utils.ReadAllLimited(f, maxSize)
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	if int64(len(data)) > maxSize {
		return utils.Fail(c, fiber.StatusBadRequest, "file too large")
	}

	var durationSec *int
	if v := c.QueryInt("duration_sec", 0); v > 0 {
		durationSec = &v
	} else if d := c.FormValue("duration_sec"); d != "" {
		if parsed, err := strconv.Atoi(d); err == nil && parsed > 0 {
			durationSec = &parsed
		}
	}

	var replyToID *uuid.UUID
	if r := c.FormValue("reply_to_id"); r != "" {
		id, err := uuid.Parse(r)
		if err == nil {
			replyToID = &id
		}
	}

	filename := file.Filename
	msg, err := h.messages.SendMedia(c.Context(), chatID, userID, msgType, data, filename, durationSec, replyToID)
	if err != nil {
		if errors.Is(err, services.ErrNotMember) {
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, msg)
}

func (h *MessageHandler) Edit(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	messageID, err := uuid.Parse(c.Params("messageId"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid message id")
	}
	var req editMessageReq
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}
	msg, err := h.messages.EditText(c.Context(), chatID, userID, messageID, req.Content)
	if err != nil {
		if errors.Is(err, services.ErrNotMember) {
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, msg)
}

func (h *MessageHandler) Delete(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	messageID, err := uuid.Parse(c.Params("messageId"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid message id")
	}
	msg, err := h.messages.Delete(c.Context(), chatID, userID, messageID)
	if err != nil {
		if errors.Is(err, services.ErrNotMember) {
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, msg)
}

func (h *MessageHandler) MarkRead(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	var req markReadReq
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}
	if err := h.messages.MarkRead(c.Context(), chatID, userID, req.MessageID); err != nil {
		if errors.Is(err, services.ErrNotMember) {
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, fiber.Map{"read": true})
}

type forwardReq struct {
	SourceChatID uuid.UUID `json:"source_chat_id" validate:"required"`
	MessageID    uuid.UUID `json:"message_id" validate:"required"`
}

// Forward copies a message from `source_chat_id` into the URL chat. Caller
// must be a member of both. See `MessageService.Forward` for details.
func (h *MessageHandler) Forward(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	targetChatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	var req forwardReq
	if err := middleware.ValidateBody(c, &req); err != nil {
		return err
	}
	msg, err := h.messages.Forward(c.Context(), targetChatID, req.SourceChatID, req.MessageID, userID)
	if err != nil {
		if errors.Is(err, services.ErrNotMember) {
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, msg)
}

func (h *MessageHandler) Pin(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	messageID, err := uuid.Parse(c.Params("messageId"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid message id")
	}
	msg, err := h.messages.Pin(c.Context(), chatID, messageID, userID)
	if err != nil {
		switch {
		case errors.Is(err, services.ErrNotMember):
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		case errors.Is(err, services.ErrForbidden):
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		case errors.Is(err, services.ErrChatNotFound):
			return utils.Fail(c, fiber.StatusNotFound, err.Error())
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, msg)
}

func (h *MessageHandler) Unpin(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	messageID, err := uuid.Parse(c.Params("messageId"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid message id")
	}
	msg, err := h.messages.Unpin(c.Context(), chatID, messageID, userID)
	if err != nil {
		switch {
		case errors.Is(err, services.ErrNotMember):
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		case errors.Is(err, services.ErrForbidden):
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		case errors.Is(err, services.ErrChatNotFound):
			return utils.Fail(c, fiber.StatusNotFound, err.Error())
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, msg)
}

func (h *MessageHandler) ListPinned(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	msgs, err := h.messages.ListPinned(c.Context(), chatID, userID)
	if err != nil {
		if errors.Is(err, services.ErrNotMember) {
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		}
		return utils.Fail(c, fiber.StatusInternalServerError, err.Error())
	}
	if msgs == nil {
		msgs = []models.Message{}
	}
	return utils.OK(c, fiber.Map{"messages": msgs})
}

func (h *MessageHandler) Search(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	q := c.Query("q")
	limit := c.QueryInt("limit", 50)
	msgs, err := h.messages.Search(c.Context(), chatID, userID, q, limit)
	if err != nil {
		if errors.Is(err, services.ErrNotMember) {
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		}
		return utils.Fail(c, fiber.StatusInternalServerError, err.Error())
	}
	if msgs == nil {
		msgs = []models.Message{}
	}
	return utils.OK(c, fiber.Map{"messages": msgs})
}

// Clear handles `DELETE /api/chats/:id/messages`. Direct/saved: any member.
// Group: admin/owner only. See `MessageService.ClearChat` for details.
func (h *MessageHandler) Clear(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	chatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	n, err := h.messages.ClearChat(c.Context(), chatID, userID)
	if err != nil {
		switch {
		case errors.Is(err, services.ErrNotMember):
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		case errors.Is(err, services.ErrForbidden):
			return utils.Fail(c, fiber.StatusForbidden, err.Error())
		case errors.Is(err, services.ErrChatNotFound):
			return utils.Fail(c, fiber.StatusNotFound, err.Error())
		}
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, fiber.Map{"cleared": true, "deleted_count": n})
}
