package services

import (
	"context"

	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/models"
)

func (s *MessageService) Search(ctx context.Context, chatID, callerID uuid.UUID, q string, limit int) ([]models.Message, error) {
	if err := EnsureMember(s.chats, ctx, chatID, callerID); err != nil {
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
