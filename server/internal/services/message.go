package services

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/models"
	"github.com/telegramclone/server/internal/repository"
	"github.com/telegramclone/server/internal/utils"
)

type MessageService struct {
	messages *repository.MessageRepository
	chats    *repository.ChatRepository
	users    *repository.UserRepository
	files    *utils.FileStore
	hub      *Hub
}

func NewMessageService(
	messages *repository.MessageRepository,
	chats *repository.ChatRepository,
	users *repository.UserRepository,
	files *utils.FileStore,
	hub *Hub,
) *MessageService {
	return &MessageService{
		messages: messages, chats: chats, users: users, files: files, hub: hub,
	}
}

func (s *MessageService) List(ctx context.Context, chatID, userID uuid.UUID, cursor *models.PaginationCursor, limit int) ([]models.Message, *models.PaginationCursor, error) {
	ok, err := s.chats.IsMember(ctx, chatID, userID)
	if err != nil {
		return nil, nil, err
	}
	if !ok {
		return nil, nil, ErrNotMember
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
	var next *models.PaginationCursor
	if len(msgs) == limit {
		last := msgs[len(msgs)-1]
		next = &models.PaginationCursor{CreatedAt: last.CreatedAt, ID: last.ID}
	}
	return msgs, next, nil
}

func (s *MessageService) SendText(ctx context.Context, chatID, senderID uuid.UUID, content string, replyToID *uuid.UUID) (*models.Message, error) {
	if err := s.ensureMember(ctx, chatID, senderID); err != nil {
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
	if err := s.ensureMember(ctx, chatID, senderID); err != nil {
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
	var maxSize int64

	switch msgType {
	case models.MessageTypeImage:
		category = utils.CategoryImage
		allowed = utils.AllowedImageMIMEs()
		maxSize = 20 << 20
	case models.MessageTypeVideo:
		category = utils.CategoryVideo
		allowed = utils.AllowedVideoMIMEs()
		maxSize = 100 << 20
	case models.MessageTypeVoice:
		category = utils.CategoryVoice
		allowed = utils.AllowedVoiceMIMEs()
		maxSize = 10 << 20
	case models.MessageTypeFile:
		category = utils.CategoryFile
		allowed = nil
		maxSize = 50 << 20
	default:
		return nil, errors.New("invalid message type")
	}

	if msgType != models.MessageTypeFile {
		if err := utils.ValidateMedia(mime, int64(len(data)), allowed, maxSize); err != nil {
			return nil, err
		}
	} else if int64(len(data)) > maxSize {
		return nil, errors.New("file too large")
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
	if err := s.ensureMember(ctx, chatID, userID); err != nil {
		return nil, err
	}
	msg, err := s.messages.UpdateText(ctx, messageID, userID, content)
	if err != nil {
		return nil, err
	}
	if msg == nil || msg.ChatID != chatID {
		return nil, errors.New("message not found")
	}
	s.broadcastMessageEvent(ctx, chatID, "message.updated", msg)
	return msg, nil
}

func (s *MessageService) Delete(ctx context.Context, chatID, userID, messageID uuid.UUID) (*models.Message, error) {
	if err := s.ensureMember(ctx, chatID, userID); err != nil {
		return nil, err
	}
	msg, err := s.messages.SoftDelete(ctx, messageID, userID)
	if err != nil {
		return nil, err
	}
	if msg == nil || msg.ChatID != chatID {
		return nil, errors.New("message not found")
	}
	s.broadcastMessageEvent(ctx, chatID, "message.deleted", msg)
	return msg, nil
}

func (s *MessageService) MarkRead(ctx context.Context, chatID, userID, messageID uuid.UUID) error {
	if err := s.ensureMember(ctx, chatID, userID); err != nil {
		return err
	}
	ok, err := s.messages.BelongsToChat(ctx, messageID, chatID)
	if err != nil {
		return err
	}
	if !ok {
		return errors.New("message not found")
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

func (s *MessageService) ensureMember(ctx context.Context, chatID, userID uuid.UUID) error {
	ok, err := s.chats.IsMember(ctx, chatID, userID)
	if err != nil {
		return err
	}
	if !ok {
		return ErrNotMember
	}
	return nil
}

func (s *MessageService) getMemberIDs(ctx context.Context, chatID uuid.UUID) ([]uuid.UUID, error) {
	members, err := s.chats.GetMembers(ctx, chatID)
	if err != nil {
		return nil, err
	}
	ids := make([]uuid.UUID, len(members))
	for i, m := range members {
		ids[i] = m.UserID
	}
	return ids, nil
}

func (s *MessageService) broadcastNewMessage(ctx context.Context, chatID uuid.UUID, msg *models.Message) {
	s.broadcastMessageEvent(ctx, chatID, "message.new", msg)
}

func (s *MessageService) broadcastMessageEvent(ctx context.Context, chatID uuid.UUID, eventType string, msg *models.Message) {
	memberIDs, err := s.getMemberIDs(ctx, chatID)
	if err != nil {
		return
	}
	data, _ := json.Marshal(msg)
	s.hub.Broadcast(ctx, memberIDs, WSMessage{Type: eventType, Data: data})
}

func (s *MessageService) BroadcastTyping(ctx context.Context, chatID, userID uuid.UUID, isTyping bool) {
	memberIDs, _ := s.getMemberIDs(ctx, chatID)
	filtered := make([]uuid.UUID, 0, len(memberIDs))
	for _, id := range memberIDs {
		if id != userID {
			filtered = append(filtered, id)
		}
	}
	data, _ := json.Marshal(map[string]interface{}{
		"chat_id":   chatID,
		"user_id":   userID,
		"is_typing": isTyping,
	})
	s.hub.Broadcast(ctx, filtered, WSMessage{Type: "typing", Data: data})
}

func (s *MessageService) BroadcastOnline(ctx context.Context, userID uuid.UUID, isOnline bool) {
	data, _ := json.Marshal(map[string]interface{}{
		"user_id":    userID,
		"is_online":  isOnline,
	})
	// broadcast to all connected users is expensive; notify contacts via online list
	online := s.hub.OnlineUserIDs()
	s.hub.Broadcast(ctx, online, WSMessage{Type: "user.online", Data: data})
}
