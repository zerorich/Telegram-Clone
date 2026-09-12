package services

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/models"
)

func (s *MessageService) ClearChat(ctx context.Context, chatID, callerID uuid.UUID) (int64, error) {
	chat, err := s.chats.GetByID(ctx, chatID)
	if err != nil {
		return 0, err
	}
	if chat == nil {
		return 0, ErrChatNotFound
	}
	if err := EnsureMember(s.chats, ctx, chatID, callerID); err != nil {
		return 0, err
	}
	if chat.Type == models.ChatTypeGroup {
		if err := RequireAdmin(s.chats, ctx, chatID, callerID); err != nil {
			return 0, err
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

func (s *MessageService) BroadcastChatCleared(ctx context.Context, chatID uuid.UUID, userIDs []uuid.UUID) {
	if len(userIDs) == 0 {
		return
	}
	data, _ := json.Marshal(map[string]interface{}{"chat_id": chatID})
	s.hub.Broadcast(ctx, userIDs, WSMessage{Type: "chat.cleared", Data: data})
}
