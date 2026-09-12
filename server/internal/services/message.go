package services

import (
	"context"

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
	push     *FCMSender
}

func NewMessageService(
	messages *repository.MessageRepository,
	chats *repository.ChatRepository,
	users *repository.UserRepository,
	files *utils.FileStore,
	hub *Hub,
	push *FCMSender,
) *MessageService {
	return &MessageService{
		messages: messages, chats: chats, users: users, files: files, hub: hub, push: push,
	}
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
