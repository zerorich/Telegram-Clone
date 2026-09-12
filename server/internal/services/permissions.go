package services

import (
	"context"

	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/models"
	"github.com/telegramclone/server/internal/repository"
)

func EnsureMember(chats *repository.ChatRepository, ctx context.Context, chatID, userID uuid.UUID) error {
	ok, err := chats.IsMember(ctx, chatID, userID)
	if err != nil {
		return err
	}
	if !ok {
		return ErrNotMember
	}
	return nil
}

func RequireAdmin(chats *repository.ChatRepository, ctx context.Context, chatID, userID uuid.UUID) error {
	role, err := chats.GetMemberRole(ctx, chatID, userID)
	if err != nil {
		return ErrNotMember
	}
	if role != models.RoleAdmin && role != models.RoleOwner {
		return ErrForbidden
	}
	return nil
}

func RequirePinPermission(chats *repository.ChatRepository, ctx context.Context, chatID, userID uuid.UUID) error {
	chat, err := chats.GetByID(ctx, chatID)
	if err != nil {
		return err
	}
	if chat == nil {
		return ErrChatNotFound
	}
	if err := EnsureMember(chats, ctx, chatID, userID); err != nil {
		return err
	}
	if chat.Type != models.ChatTypeGroup {
		return nil
	}
	return RequireAdmin(chats, ctx, chatID, userID)
}
