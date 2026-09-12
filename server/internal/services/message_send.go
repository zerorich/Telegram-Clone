package services

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/models"
	"github.com/telegramclone/server/internal/utils"
)

func (s *MessageService) List(ctx context.Context, chatID, userID uuid.UUID, cursor *models.PaginationCursor, limit int) ([]models.Message, *models.PaginationCursor, error) {
	if err := EnsureMember(s.chats, ctx, chatID, userID); err != nil {
		return nil, nil, err
	}
	if limit <= 0 || limit > 50 {
		limit = 50
	}
	msgs, err := s.messages.List(ctx, chatID, cursor, limit)
	if err != nil {
		return nil, nil, err
	}
	for i := range msgs {
		if msgs[i].SenderID == userID {
			read, err := s.messages.IsReadByOthers(ctx, msgs[i].ID, chatID, userID)
			if err == nil {
				msgs[i].IsRead = read
			}
		}
	}
	if err := s.PopulateForwardedUsers(ctx, msgs); err != nil {
		return nil, nil, err
	}
	var next *models.PaginationCursor
	if len(msgs) == limit {
		last := msgs[len(msgs)-1]
		next = &models.PaginationCursor{CreatedAt: last.CreatedAt, ID: last.ID}
	}
	return msgs, next, nil
}

func (s *MessageService) SendText(ctx context.Context, chatID, senderID uuid.UUID, content string, replyToID *uuid.UUID) (*models.Message, error) {
	if err := EnsureMember(s.chats, ctx, chatID, senderID); err != nil {
		return nil, err
	}
	if replyToID != nil {
		if err := s.messages.ValidateReplyInChat(ctx, *replyToID, chatID); err != nil {
			return nil, err
		}
	}
	msg := &models.Message{
		ChatID: chatID, SenderID: senderID,
		Type: models.MessageTypeText, Content: &content, ReplyToID: replyToID,
	}
	if err := s.messages.Create(ctx, msg); err != nil {
		return nil, err
	}
	s.broadcastNewMessage(ctx, chatID, msg)
	return msg, nil
}

func (s *MessageService) SendMedia(ctx context.Context, chatID, senderID uuid.UUID, msgType models.MessageType, data []byte, filename string, durationSec *int, replyToID *uuid.UUID) (*models.Message, error) {
	if err := EnsureMember(s.chats, ctx, chatID, senderID); err != nil {
		return nil, err
	}
	mime := utils.DetectMIME(data)
	if mime == "" || mime == "application/octet-stream" {
		if fallback := utils.MIMEFromFilename(filename); fallback != "" {
			mime = fallback
		}
	}
	var category utils.MediaCategory
	var allowed []string
	maxSize := utils.MaxMediaSize(msgType)

	switch msgType {
	case models.MessageTypeImage:
		category = utils.CategoryImage
		allowed = utils.AllowedImageMIMEs()
	case models.MessageTypeVideo:
		category = utils.CategoryVideo
		allowed = utils.AllowedVideoMIMEs()
	case models.MessageTypeVoice:
		category = utils.CategoryVoice
		allowed = utils.AllowedVoiceMIMEs()
	case models.MessageTypeFile:
		category = utils.CategoryFile
		allowed = nil
	default:
		return nil, ErrInvalidMessageType
	}

	if msgType != models.MessageTypeFile {
		if err := utils.ValidateMedia(mime, int64(len(data)), allowed, maxSize); err != nil {
			if errors.Is(err, utils.ErrFileTooLarge) {
				return nil, ErrFileTooLarge
			}
			return nil, ErrUnsupportedFileType
		}
	} else if int64(len(data)) > maxSize {
		return nil, ErrFileTooLarge
	}

	ext := utils.ExtForMIME(mime)
	path, err := s.files.Save(category, data, ext)
	if err != nil {
		return nil, err
	}
	if replyToID != nil {
		if err := s.messages.ValidateReplyInChat(ctx, *replyToID, chatID); err != nil {
			return nil, err
		}
	}
	msg := &models.Message{
		ChatID: chatID, SenderID: senderID, Type: msgType,
		MediaURL: &path, DurationSec: durationSec, ReplyToID: replyToID,
	}
	if err := s.messages.Create(ctx, msg); err != nil {
		return nil, err
	}
	s.broadcastNewMessage(ctx, chatID, msg)
	return msg, nil
}

func (s *MessageService) EditText(ctx context.Context, chatID, userID, messageID uuid.UUID, content string) (*models.Message, error) {
	if err := EnsureMember(s.chats, ctx, chatID, userID); err != nil {
		return nil, err
	}
	msg, err := s.messages.UpdateText(ctx, messageID, userID, content)
	if err != nil {
		return nil, err
	}
	if msg == nil || msg.ChatID != chatID {
		return nil, ErrMessageNotFound
	}
	s.broadcastMessageEvent(ctx, chatID, "message.updated", msg)
	return msg, nil
}

func (s *MessageService) Delete(ctx context.Context, chatID, userID, messageID uuid.UUID) (*models.Message, error) {
	if err := EnsureMember(s.chats, ctx, chatID, userID); err != nil {
		return nil, err
	}
	msg, err := s.messages.SoftDelete(ctx, messageID, userID)
	if err != nil {
		return nil, err
	}
	if msg == nil || msg.ChatID != chatID {
		return nil, ErrMessageNotFound
	}
	s.broadcastMessageEvent(ctx, chatID, "message.deleted", msg)
	return msg, nil
}

func (s *MessageService) MarkRead(ctx context.Context, chatID, userID, messageID uuid.UUID) error {
	if err := EnsureMember(s.chats, ctx, chatID, userID); err != nil {
		return err
	}
	ok, err := s.messages.BelongsToChat(ctx, messageID, chatID)
	if err != nil {
		return err
	}
	if !ok {
		return ErrMessageNotFound
	}
	if _, err := s.messages.MarkReadUpTo(ctx, chatID, userID, messageID); err != nil {
		return err
	}
	memberIDs, err := s.getMemberIDs(ctx, chatID)
	if err != nil {
		return err
	}
	data, _ := json.Marshal(map[string]interface{}{
		"chat_id":    chatID,
		"message_id": messageID,
		"user_id":    userID,
	})
	s.hub.Broadcast(ctx, memberIDs, WSMessage{Type: "message.read", Data: data})
	return nil
}
