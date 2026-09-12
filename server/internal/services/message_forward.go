package services

import (
	"context"

	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/models"
)

// Forward copies an existing message from `sourceChatID` into `targetChatID`.
// Caller must be a member of BOTH chats. Soft-deleted source messages are
// rejected so callers don't end up with empty bubbles.
func (s *MessageService) Forward(ctx context.Context, targetChatID, sourceChatID, messageID, callerID uuid.UUID) (*models.Message, error) {
	if err := EnsureMember(s.chats, ctx, targetChatID, callerID); err != nil {
		return nil, err
	}
	if err := EnsureMember(s.chats, ctx, sourceChatID, callerID); err != nil {
		return nil, err
	}
	src, err := s.messages.GetByID(ctx, messageID)
	if err != nil {
		return nil, err
	}
	if src == nil || src.ChatID != sourceChatID {
		return nil, ErrSourceMessageNotFound
	}
	if src.IsDeleted {
		return nil, ErrCannotForwardDeleted
	}

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
	batch := []models.Message{*msg}
	if err := s.PopulateForwardedUsers(ctx, batch); err == nil {
		msg.ForwardedFromUser = batch[0].ForwardedFromUser
	}
	s.broadcastNewMessage(ctx, targetChatID, msg)
	return msg, nil
}

// SaveToFavorites is "forward to my Saved chat" — the user-visible save action.
// Auto-creates the saved chat on first call.
func (s *MessageService) SaveToFavorites(ctx context.Context, sourceChatID, messageID, callerID uuid.UUID) (*models.Message, error) {
	saved, err := s.chats.GetOrCreateSavedChat(ctx, callerID)
	if err != nil {
		return nil, err
	}
	return s.Forward(ctx, saved.ID, sourceChatID, messageID, callerID)
}
