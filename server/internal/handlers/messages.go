package handlers

import (
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/httperr"
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
		return httperr.Respond(c, err)
	}
	limit := c.QueryInt("limit", 50)
	msgs, next, err := h.messages.List(c.Context(), chatID, userID, cursor, limit)
	if err != nil {
		return httperr.Respond(c, err)
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
		return httperr.Respond(c, err)
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
		return httperr.BadRequest(c, "invalid file")
	}
	defer f.Close()

	maxSize := utils.MaxMediaSize(msgType)
	data, err := utils.ReadAllLimited(f, maxSize)
	if err != nil {
		return httperr.Respond(c, err)
	}
	if int64(len(data)) > maxSize {
		return httperr.Respond(c, services.ErrFileTooLarge)
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

	msg, err := h.messages.SendMedia(c.Context(), chatID, userID, msgType, data, file.Filename, durationSec, replyToID)
	if err != nil {
		return httperr.Respond(c, err)
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
		return httperr.Respond(c, err)
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
		return httperr.Respond(c, err)
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
		return httperr.Respond(c, err)
	}
	return utils.OK(c, fiber.Map{"read": true})
}

type forwardReq struct {
	SourceChatID uuid.UUID `json:"source_chat_id" validate:"required"`
	MessageID    uuid.UUID `json:"message_id" validate:"required"`
}

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
		return httperr.Respond(c, err)
	}
	return utils.OK(c, msg)
}

func (h *MessageHandler) SaveToFavorites(c *fiber.Ctx) error {
	userID, err := middleware.GetUserID(c)
	if err != nil {
		return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
	}
	sourceChatID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid chat id")
	}
	messageID, err := uuid.Parse(c.Params("messageId"))
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid message id")
	}
	msg, err := h.messages.SaveToFavorites(c.Context(), sourceChatID, messageID, userID)
	if err != nil {
		return httperr.Respond(c, err)
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
		return httperr.Respond(c, err)
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
		return httperr.Respond(c, err)
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
		return httperr.Respond(c, err)
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
		return httperr.Respond(c, err)
	}
	if msgs == nil {
		msgs = []models.Message{}
	}
	return utils.OK(c, fiber.Map{"messages": msgs})
}

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
		return httperr.Respond(c, err)
	}
	return utils.OK(c, fiber.Map{"cleared": true, "deleted_count": n})
}
