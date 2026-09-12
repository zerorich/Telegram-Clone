package services

import (
	"context"

	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/models"
)

func (s *MessageService) Pin(ctx context.Context, chatID, messageID, callerID uuid.UUID) (*models.Message, error) {
	if err := RequirePinPermission(s.chats, ctx, chatID, callerID); err != nil {
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
	if err := RequirePinPermission(s.chats, ctx, chatID, callerID); err != nil {
		return nil, err
	}
	msg, err := s.messages.Unpin(ctx, messageID, chatID)
	if err != nil {
		return nil, err
	}
	s.broadcastMessageEvent(ctx, chatID, "message.unpinned", msg)
	return msg, nil
}

func (s *MessageService) ListPinned(ctx context.Context, chatID, callerID uuid.UUID) ([]models.Message, error) {
	if err := EnsureMember(s.chats, ctx, chatID, callerID); err != nil {
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
