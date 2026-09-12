package services

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/models"
)

func (s *MessageService) broadcastNewMessage(ctx context.Context, chatID uuid.UUID, msg interface{}) {
	s.broadcastMessageEvent(ctx, chatID, "message.new", msg)
	s.notifyOfflineMembers(ctx, chatID, msg)
}

func (s *MessageService) notifyOfflineMembers(ctx context.Context, chatID uuid.UUID, raw interface{}) {
	if s.push == nil || !s.push.Enabled() {
		return
	}
	msg, ok := raw.(*models.Message)
	if !ok || msg == nil {
		return
	}
	memberIDs, err := s.getMemberIDs(ctx, chatID)
	if err != nil {
		return
	}
	offline := make([]uuid.UUID, 0, len(memberIDs))
	for _, id := range memberIDs {
		if id == msg.SenderID {
			continue
		}
		if !s.hub.IsOnline(id) {
			offline = append(offline, id)
		}
	}
	if len(offline) == 0 {
		return
	}
	devices, err := s.users.ListPushTokens(ctx, offline)
	if err != nil || len(devices) == 0 {
		return
	}
	tokens := make([]string, 0, len(devices))
	for _, d := range devices {
		tokens = append(tokens, d.Token)
	}
	title := "Новое сообщение"
	if sender, err := s.users.GetByID(ctx, msg.SenderID); err == nil && sender != nil && sender.Name != "" {
		title = sender.Name
		if sender.Surname != nil && *sender.Surname != "" {
			title = sender.Name + " " + *sender.Surname
		}
	}
	body := pushPreview(msg)
	s.push.NotifyNewMessage(ctx, tokens, title, body, chatID.String(), msg.ID.String())
}

func pushPreview(msg *models.Message) string {
	if msg.Content != nil && *msg.Content != "" {
		return *msg.Content
	}
	switch msg.Type {
	case models.MessageTypeImage:
		return "Фото"
	case models.MessageTypeVideo:
		return "Видео"
	case models.MessageTypeVoice:
		return "Голосовое сообщение"
	case models.MessageTypeFile:
		return "Файл"
	default:
		return "Новое сообщение"
	}
}

func (s *MessageService) broadcastMessageEvent(ctx context.Context, chatID uuid.UUID, eventType string, msg interface{}) {
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
		"user_id":   userID,
		"is_online": isOnline,
	})
	online := s.hub.OnlineUserIDs()
	s.hub.Broadcast(ctx, online, WSMessage{Type: "user.online", Data: data})
}
