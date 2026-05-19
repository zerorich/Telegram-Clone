package services

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/models"
	"github.com/telegramclone/server/internal/repository"
	"github.com/telegramclone/server/internal/utils"
)

var (
	ErrNotMember      = errors.New("not a chat member")
	ErrForbidden      = errors.New("forbidden")
	ErrChatNotFound   = errors.New("chat not found")
)

type ChatService struct {
	chats *repository.ChatRepository
	users *repository.UserRepository
	files *utils.FileStore
}

func NewChatService(chats *repository.ChatRepository, users *repository.UserRepository, files *utils.FileStore) *ChatService {
	return &ChatService{chats: chats, users: users, files: files}
}

func (s *ChatService) List(ctx context.Context, userID uuid.UUID) ([]models.ChatListItem, error) {
	items, err := s.chats.ListForUser(ctx, userID)
	if err != nil || len(items) == 0 {
		return items, err
	}
	ids := make([]uuid.UUID, len(items))
	for i := range items {
		ids[i] = items[i].ID
	}
	membersByChat, err := s.chats.GetMembersForChats(ctx, ids)
	if err != nil {
		return nil, err
	}
	for i := range items {
		items[i].Members = membersByChat[items[i].ID]
		s.SanitizeMembers(items[i].Members)
	}
	return items, nil
}

func (s *ChatService) Get(ctx context.Context, chatID, userID uuid.UUID) (*models.Chat, []models.ChatMember, error) {
	member, err := s.chats.IsMember(ctx, chatID, userID)
	if err != nil {
		return nil, nil, err
	}
	if !member {
		return nil, nil, ErrNotMember
	}
	chat, err := s.chats.GetByID(ctx, chatID)
	if err != nil {
		return nil, nil, err
	}
	if chat == nil {
		return nil, nil, ErrChatNotFound
	}
	members, err := s.chats.GetMembers(ctx, chatID)
	return chat, members, err
}

func (s *ChatService) CreateDirect(ctx context.Context, userID, otherID uuid.UUID) (*models.Chat, error) {
	if userID == otherID {
		return nil, errors.New("cannot chat with yourself")
	}
	other, err := s.users.GetByID(ctx, otherID)
	if err != nil {
		return nil, err
	}
	if other == nil {
		return nil, errors.New("user not found")
	}
	existing, err := s.chats.FindDirectChat(ctx, userID, otherID)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return existing, nil
	}
	chat := &models.Chat{Type: models.ChatTypeDirect, CreatedBy: &userID}
	if err := s.chats.Create(ctx, chat); err != nil {
		return nil, err
	}
	if err := s.chats.AddMember(ctx, chat.ID, userID, models.RoleMember); err != nil {
		return nil, err
	}
	if err := s.chats.AddMember(ctx, chat.ID, otherID, models.RoleMember); err != nil {
		return nil, err
	}
	return chat, nil
}

func (s *ChatService) CreateGroup(ctx context.Context, userID uuid.UUID, name string, memberIDs []uuid.UUID, avatarData []byte) (*models.Chat, error) {
	ids := uniqueUUIDs(append(memberIDs, userID))
	if err := s.users.ValidateIDsExist(ctx, ids); err != nil {
		return nil, err
	}
	chat := &models.Chat{
		Type: models.ChatTypeGroup, Name: &name, CreatedBy: &userID,
	}
	if len(avatarData) > 0 {
		processed, ext, err := utils.ProcessAvatar(avatarData)
		if err != nil {
			return nil, err
		}
		path, err := s.files.Save(utils.CategoryAvatar, processed, ext)
		if err != nil {
			return nil, err
		}
		chat.AvatarURL = &path
	}
	if err := s.chats.Create(ctx, chat); err != nil {
		return nil, err
	}
	if err := s.chats.AddMember(ctx, chat.ID, userID, models.RoleOwner); err != nil {
		return nil, err
	}
	for _, mid := range memberIDs {
		if mid == userID {
			continue
		}
		role := models.RoleMember
		if err := s.chats.AddMember(ctx, chat.ID, mid, role); err != nil {
			return nil, err
		}
	}
	return chat, nil
}

func (s *ChatService) UpdateGroup(ctx context.Context, chatID, userID uuid.UUID, name, avatarURL *string, avatarData []byte) (*models.Chat, error) {
	if err := s.requireAdmin(ctx, chatID, userID); err != nil {
		return nil, err
	}
	if len(avatarData) > 0 {
		processed, ext, err := utils.ProcessAvatar(avatarData)
		if err != nil {
			return nil, err
		}
		path, err := s.files.Save(utils.CategoryAvatar, processed, ext)
		if err != nil {
			return nil, err
		}
		avatarURL = &path
	}
	return s.chats.Update(ctx, chatID, name, avatarURL)
}

func (s *ChatService) AddMembers(ctx context.Context, chatID, userID uuid.UUID, memberIDs []uuid.UUID) error {
	if err := s.requireAdmin(ctx, chatID, userID); err != nil {
		return err
	}
	chat, err := s.chats.GetByID(ctx, chatID)
	if err != nil || chat == nil {
		return ErrChatNotFound
	}
	if chat.Type != models.ChatTypeGroup {
		return errors.New("cannot add members to direct chat")
	}
	if err := s.users.ValidateIDsExist(ctx, memberIDs); err != nil {
		return err
	}
	for _, mid := range memberIDs {
		if err := s.chats.AddMember(ctx, chatID, mid, models.RoleMember); err != nil {
			return err
		}
	}
	return nil
}

func (s *ChatService) RemoveMember(ctx context.Context, chatID, actorID, targetID uuid.UUID) error {
	if err := s.requireAdmin(ctx, chatID, actorID); err != nil {
		return err
	}
	return s.chats.RemoveMember(ctx, chatID, targetID)
}

func (s *ChatService) Leave(ctx context.Context, chatID, userID uuid.UUID) error {
	chat, err := s.chats.GetByID(ctx, chatID)
	if err != nil || chat == nil {
		return ErrChatNotFound
	}
	if chat.Type == models.ChatTypeDirect {
		return errors.New("cannot leave direct chat")
	}
	return s.chats.RemoveMember(ctx, chatID, userID)
}

func (s *ChatService) GetMemberUserIDs(ctx context.Context, chatID uuid.UUID) ([]uuid.UUID, error) {
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

func (s *ChatService) requireAdmin(ctx context.Context, chatID, userID uuid.UUID) error {
	role, err := s.chats.GetMemberRole(ctx, chatID, userID)
	if err != nil {
		return ErrNotMember
	}
	if role != models.RoleAdmin && role != models.RoleOwner {
		return ErrForbidden
	}
	return nil
}

func (s *ChatService) EnsureMember(ctx context.Context, chatID, userID uuid.UUID) error {
	ok, err := s.chats.IsMember(ctx, chatID, userID)
	if err != nil {
		return err
	}
	if !ok {
		return ErrNotMember
	}
	return nil
}

func uniqueUUIDs(ids []uuid.UUID) []uuid.UUID {
	seen := make(map[uuid.UUID]struct{})
	var out []uuid.UUID
	for _, id := range ids {
		if _, ok := seen[id]; !ok {
			seen[id] = struct{}{}
			out = append(out, id)
		}
	}
	return out
}

func (s *ChatService) SanitizeMembers(members []models.ChatMember) {
	for i := range members {
		if members[i].User != nil {
			members[i].User.PasswordHash = ""
		}
	}
}