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

// Forward copies an existing message from `sourceChatID` into `targetChatID`.
// Caller must be a member of BOTH chats. Soft-deleted source messages are
// rejected with a 400-ish error so callers don't end up with empty bubbles.
//
// When forwarding a message that is itself a forward, the original author
// chain is preserved (we don't accumulate "forwarded from X who forwarded from
// Y" — the outermost source wins, matching how Telegram itself behaves).
func (s *MessageService) Forward(ctx context.Context, targetChatID, sourceChatID, messageID, callerID uuid.UUID) (*models.Message, error) {
	if err := s.ensureMember(ctx, targetChatID, callerID); err != nil {
		return nil, err
	}
	if err := s.ensureMember(ctx, sourceChatID, callerID); err != nil {
		return nil, err
	}
	src, err := s.messages.GetByID(ctx, messageID)
	if err != nil {
		return nil, err
	}
	if src == nil || src.ChatID != sourceChatID {
		return nil, errors.New("source message not found")
	}
	if src.IsDeleted {
		return nil, errors.New("cannot forward a deleted message")
	}

	// Preserve original author through chained forwards.
	originUserID := src.SenderID
	if src.ForwardedFromUserID != nil {
		originUserID = *src.ForwardedFromUserID
	}
	originChatID := src.ChatID
	if src.ForwardedFromChatID != nil {
		originChatID = *src.ForwardedFromChatID
	}

	msg := &models.Message{
		ChatID:              targetChatID,
		SenderID:            callerID,
		Type:                src.Type,
		Content:             src.Content,
		MediaURL:            src.MediaURL,
		DurationSec:         src.DurationSec,
		ForwardedFromUserID: &originUserID,
		ForwardedFromChatID: &originChatID,
	}
	if err := s.messages.Create(ctx, msg); err != nil {
		return nil, err
	}
	// Populate the original-sender object so the WS payload + HTTP response
	// both carry it (clients render "Forwarded from <name>" without a refetch).
	batch := []models.Message{*msg}
	if err := s.PopulateForwardedUsers(ctx, batch); err == nil {
		msg.ForwardedFromUser = batch[0].ForwardedFromUser
	}
	s.broadcastNewMessage(ctx, targetChatID, msg)
	return msg, nil
}

// SaveToFavorites is "forward to my Saved chat" — the user-visible "Сохранить"
// action. Auto-creates the saved chat on first call.
func (s *MessageService) SaveToFavorites(ctx context.Context, sourceChatID, messageID, callerID uuid.UUID) (*models.Message, error) {
	saved, err := s.chats.GetOrCreateSavedChat(ctx, callerID)
	if err != nil {
		return nil, err
	}
	return s.Forward(ctx, saved.ID, sourceChatID, messageID, callerID)
}

// Pin marks a message as pinned. Direct chats: any member. Group: admin/owner.
// Saved chats: owner (and they're the only member, so this collapses).
func (s *MessageService) Pin(ctx context.Context, chatID, messageID, callerID uuid.UUID) (*models.Message, error) {
	if err := s.requirePinPermission(ctx, chatID, callerID); err != nil {
		return nil, err
	}
	msg, err := s.messages.Pin(ctx, messageID, chatID)
	if err != nil {
		return nil, err
	}
	s.broadcastMessageEvent(ctx, chatID, "message.pinned", msg)
	return msg, nil
}

func (s *MessageService) Unpin(ctx context.Context, chatID, messageID, callerID uuid.UUID) (*models.Message, error) {
	if err := s.requirePinPermission(ctx, chatID, callerID); err != nil {
		return nil, err
	}
	msg, err := s.messages.Unpin(ctx, messageID, chatID)
	if err != nil {
		return nil, err
	}
	s.broadcastMessageEvent(ctx, chatID, "message.unpinned", msg)
	return msg, nil
}

// ListPinned returns the chat's pinned messages, newest-pin first. Caller must
// be a member.
func (s *MessageService) ListPinned(ctx context.Context, chatID, callerID uuid.UUID) ([]models.Message, error) {
	if err := s.ensureMember(ctx, chatID, callerID); err != nil {
		return nil, err
	}
	msgs, err := s.messages.ListPinned(ctx, chatID, 50)
	if err != nil {
		return nil, err
	}
	if err := s.PopulateForwardedUsers(ctx, msgs); err != nil {
		return nil, err
	}
	return msgs, nil
}

// Search runs a chat-scoped ILIKE over message content. `q` is required;
// `limit` is clamped to 100 server-side.
func (s *MessageService) Search(ctx context.Context, chatID, callerID uuid.UUID, q string, limit int) ([]models.Message, error) {
	if err := s.ensureMember(ctx, chatID, callerID); err != nil {
		return nil, err
	}
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	msgs, err := s.messages.Search(ctx, chatID, q, limit)
	if err != nil {
		return nil, err
	}
	if err := s.PopulateForwardedUsers(ctx, msgs); err != nil {
		return nil, err
	}
	return msgs, nil
}

// ClearChat hard-deletes every message in a chat. Auth:
//   - direct/saved: any member (both parties see the chat go empty for direct)
//   - group:        admin/owner only
//
// Emits `chat.cleared` to all current members so their UIs can wipe.
func (s *MessageService) ClearChat(ctx context.Context, chatID, callerID uuid.UUID) (int64, error) {
	chat, err := s.chats.GetByID(ctx, chatID)
	if err != nil {
		return 0, err
	}
	if chat == nil {
		return 0, ErrChatNotFound
	}
	if err := s.ensureMember(ctx, chatID, callerID); err != nil {
		return 0, err
	}
	if chat.Type == models.ChatTypeGroup {
		role, err := s.chats.GetMemberRole(ctx, chatID, callerID)
		if err != nil {
			return 0, ErrNotMember
		}
		if role != models.RoleAdmin && role != models.RoleOwner {
			return 0, ErrForbidden
		}
	}
	memberIDs, err := s.getMemberIDs(ctx, chatID)
	if err != nil {
		return 0, err
	}
	n, err := s.messages.ClearChat(ctx, chatID)
	if err != nil {
		return 0, err
	}
	s.BroadcastChatCleared(ctx, chatID, memberIDs)
	return n, nil
}

// PopulateForwardedUsers fills `ForwardedFromUser` on every message that has
// `forwarded_from_user_id`. Batches into one users-by-IDs query.
func (s *MessageService) PopulateForwardedUsers(ctx context.Context, msgs []models.Message) error {
	if len(msgs) == 0 {
		return nil
	}
	idSet := make(map[uuid.UUID]struct{})
	for i := range msgs {
		if msgs[i].ForwardedFromUserID != nil {
			idSet[*msgs[i].ForwardedFromUserID] = struct{}{}
		}
	}
	if len(idSet) == 0 {
		return nil
	}
	ids := make([]uuid.UUID, 0, len(idSet))
	for id := range idSet {
		ids = append(ids, id)
	}
	byID, err := s.users.GetByIDs(ctx, ids)
	if err != nil {
		return err
	}
	for i := range msgs {
		if msgs[i].ForwardedFromUserID == nil {
			continue
		}
		if u, ok := byID[*msgs[i].ForwardedFromUserID]; ok && u != nil {
			u.PasswordHash = ""
			msgs[i].ForwardedFromUser = u
		}
	}
	return nil
}

func (s *MessageService) requirePinPermission(ctx context.Context, chatID, userID uuid.UUID) error {
	chat, err := s.chats.GetByID(ctx, chatID)
	if err != nil {
		return err
	}
	if chat == nil {
		return ErrChatNotFound
	}
	if err := s.ensureMember(ctx, chatID, userID); err != nil {
		return err
	}
	if chat.Type != models.ChatTypeGroup {
		return nil
	}
	role, err := s.chats.GetMemberRole(ctx, chatID, userID)
	if err != nil {
		return ErrNotMember
	}
	if role != models.RoleAdmin && role != models.RoleOwner {
		return ErrForbidden
	}
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

// BroadcastChatCleared notifies the supplied users (typically the chat's
// current member set, fetched BEFORE any mutation if order matters) that the
// chat history has been wiped. ChatService has its own helpers for the other
// chat-level events (`chat.deleted`, `chat.muted`).
func (s *MessageService) BroadcastChatCleared(ctx context.Context, chatID uuid.UUID, userIDs []uuid.UUID) {
	if len(userIDs) == 0 {
		return
	}
	data, _ := json.Marshal(map[string]interface{}{"chat_id": chatID})
	s.hub.Broadcast(ctx, userIDs, WSMessage{Type: "chat.cleared", Data: data})
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
		"user_id":   userID,
		"is_online": isOnline,
	})
	// broadcast to all connected users is expensive; notify contacts via online list
	online := s.hub.OnlineUserIDs()
	s.hub.Broadcast(ctx, online, WSMessage{Type: "user.online", Data: data})
}
