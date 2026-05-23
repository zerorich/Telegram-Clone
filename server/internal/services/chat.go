package services

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/models"
	"github.com/telegramclone/server/internal/repository"
	"github.com/telegramclone/server/internal/utils"
)

var (
	ErrNotMember          = errors.New("not a chat member")
	ErrForbidden          = errors.New("forbidden")
	ErrChatNotFound       = errors.New("chat not found")
	ErrCannotDeleteSaved  = errors.New("cannot delete saved messages chat")
)

type ChatService struct {
	chats *repository.ChatRepository
	users *repository.UserRepository
	files *utils.FileStore
	hub   *Hub
}

// NewChatService now takes a Hub so chat-level events (chat.deleted,
// chat.muted) can be broadcast without round-tripping through MessageService.
func NewChatService(chats *repository.ChatRepository, users *repository.UserRepository, files *utils.FileStore, hub *Hub) *ChatService {
	return &ChatService{chats: chats, users: users, files: files, hub: hub}
}

func (s *ChatService) List(ctx context.Context, userID uuid.UUID) ([]models.ChatListItem, error) {
	// Ensure the user's Saved chat exists so it shows up in the list on the
	// very first call. Idempotent — a no-op for returning users.
	if _, err := s.chats.GetOrCreateSavedChat(ctx, userID); err != nil {
		return nil, err
	}
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

// GetSaved returns the caller's Saved chat (creating it on first access) as a
// `ChatListItem` envelope so the response shape matches `GET /chats/:id`.
func (s *ChatService) GetSaved(ctx context.Context, userID uuid.UUID) (*models.ChatListItem, error) {
	chat, err := s.chats.GetOrCreateSavedChat(ctx, userID)
	if err != nil {
		return nil, err
	}
	members, err := s.chats.GetMembers(ctx, chat.ID)
	if err != nil {
		return nil, err
	}
	s.SanitizeMembers(members)
	return &models.ChatListItem{
		Chat:    *chat,
		Members: members,
	}, nil
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

	// Create chat + both members atomically: otherwise a failed second AddMember
	// would leave a half-created direct chat with only one party.
	tx, err := s.chats.BeginTx(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txChats := s.chats.WithTx(tx)

	chat := &models.Chat{Type: models.ChatTypeDirect, CreatedBy: &userID}
	if err := txChats.Create(ctx, chat); err != nil {
		return nil, err
	}
	if err := txChats.AddMember(ctx, chat.ID, userID, models.RoleMember); err != nil {
		return nil, err
	}
	if err := txChats.AddMember(ctx, chat.ID, otherID, models.RoleMember); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
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

	// Group creation = 1 chat row + N member rows. Any partial failure leaves
	// orphaned data; wrap the writes in a transaction.
	tx, err := s.chats.BeginTx(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txChats := s.chats.WithTx(tx)

	if err := txChats.Create(ctx, chat); err != nil {
		return nil, err
	}
	if err := txChats.AddMember(ctx, chat.ID, userID, models.RoleOwner); err != nil {
		return nil, err
	}
	for _, mid := range memberIDs {
		if mid == userID {
			continue
		}
		if err := txChats.AddMember(ctx, chat.ID, mid, models.RoleMember); err != nil {
			return nil, err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
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

	tx, err := s.chats.BeginTx(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	txChats := s.chats.WithTx(tx)

	for _, mid := range memberIDs {
		if err := txChats.AddMember(ctx, chatID, mid, models.RoleMember); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
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

// Mute upserts the (user, chat) mute row. `until == nil` means "muted with no
// expiry". Caller must be a chat member; muting the Saved chat is allowed
// because the user can still want a quiet self-notebook.
func (s *ChatService) Mute(ctx context.Context, chatID, userID uuid.UUID, until *time.Time) (*models.ChatMute, error) {
	if err := s.EnsureMember(ctx, chatID, userID); err != nil {
		return nil, err
	}
	m, err := s.chats.UpsertMute(ctx, userID, chatID, until)
	if err != nil {
		return nil, err
	}
	s.broadcastChatMuted(ctx, chatID, userID, until)
	return m, nil
}

func (s *ChatService) Unmute(ctx context.Context, chatID, userID uuid.UUID) error {
	if err := s.EnsureMember(ctx, chatID, userID); err != nil {
		return err
	}
	if err := s.chats.DeleteMute(ctx, userID, chatID); err != nil {
		return err
	}
	s.broadcastChatMuted(ctx, chatID, userID, nil)
	return nil
}

// Delete dispatches on chat type:
//
//   - saved:  always rejected (the saved chat is permanent).
//   - direct: drop the caller's membership; if the other side has also left,
//             nuke the chat row (cascades delete messages). Notify both
//             previously-affected users via `chat.deleted`.
//   - group:  alias for Leave (idempotent — leaving a chat the user has
//             already left is a no-op).
func (s *ChatService) Delete(ctx context.Context, chatID, userID uuid.UUID) error {
	chat, err := s.chats.GetByID(ctx, chatID)
	if err != nil {
		return err
	}
	if chat == nil {
		return ErrChatNotFound
	}
	switch chat.Type {
	case models.ChatTypeSaved:
		if chat.CreatedBy == nil || *chat.CreatedBy != userID {
			return ErrForbidden
		}
		return ErrCannotDeleteSaved
	case models.ChatTypeGroup:
		// Idempotent: not-a-member is a successful no-op so a client retry
		// after a network blip doesn't surface a confusing 400.
		ok, err := s.chats.IsMember(ctx, chatID, userID)
		if err != nil {
			return err
		}
		if !ok {
			return nil
		}
		return s.chats.RemoveMember(ctx, chatID, userID)
	case models.ChatTypeDirect:
		// Capture the previous member set BEFORE mutating so the broadcast
		// reaches the other party even if they were the last one out.
		memberIDs, err := s.GetMemberUserIDs(ctx, chatID)
		if err != nil {
			return err
		}
		if err := s.chats.RemoveMember(ctx, chatID, userID); err != nil {
			return err
		}
		remaining, err := s.chats.MemberCount(ctx, chatID)
		if err != nil {
			return err
		}
		if remaining == 0 {
			if err := s.chats.Delete(ctx, chatID); err != nil {
				return err
			}
		}
		s.broadcastChatDeleted(ctx, chatID, memberIDs)
		return nil
	default:
		return errors.New("unsupported chat type")
	}
}

func (s *ChatService) broadcastChatDeleted(ctx context.Context, chatID uuid.UUID, userIDs []uuid.UUID) {
	if s.hub == nil || len(userIDs) == 0 {
		return
	}
	data, _ := json.Marshal(map[string]interface{}{"chat_id": chatID})
	s.hub.Broadcast(ctx, userIDs, WSMessage{Type: "chat.deleted", Data: data})
}

func (s *ChatService) broadcastChatMuted(ctx context.Context, chatID, userID uuid.UUID, until *time.Time) {
	if s.hub == nil {
		return
	}
	data, _ := json.Marshal(map[string]interface{}{
		"chat_id":     chatID,
		"muted_until": until,
	})
	s.hub.Broadcast(ctx, []uuid.UUID{userID}, WSMessage{Type: "chat.muted", Data: data})
}