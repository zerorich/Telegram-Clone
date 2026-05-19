package repository

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/telegramclone/server/internal/models"
)

type ChatRepository struct {
	pool *pgxpool.Pool
}

func NewChatRepository(pool *pgxpool.Pool) *ChatRepository {
	return &ChatRepository{pool: pool}
}

func (r *ChatRepository) Create(ctx context.Context, chat *models.Chat) error {
	return r.pool.QueryRow(ctx, `
		INSERT INTO chats (type, name, avatar_url, created_by)
		VALUES ($1, $2, $3, $4)
		RETURNING id, created_at`,
		chat.Type, chat.Name, chat.AvatarURL, chat.CreatedBy,
	).Scan(&chat.ID, &chat.CreatedAt)
}

func (r *ChatRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Chat, error) {
	var c models.Chat
	err := r.pool.QueryRow(ctx, `
		SELECT id, type, name, avatar_url, created_by, created_at FROM chats WHERE id = $1`, id,
	).Scan(&c.ID, &c.Type, &c.Name, &c.AvatarURL, &c.CreatedBy, &c.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return &c, err
}

func (r *ChatRepository) Update(ctx context.Context, id uuid.UUID, name, avatarURL *string) (*models.Chat, error) {
	var c models.Chat
	err := r.pool.QueryRow(ctx, `
		UPDATE chats SET
			name = COALESCE($2, name),
			avatar_url = COALESCE($3, avatar_url)
		WHERE id = $1
		RETURNING id, type, name, avatar_url, created_by, created_at`,
		id, name, avatarURL,
	).Scan(&c.ID, &c.Type, &c.Name, &c.AvatarURL, &c.CreatedBy, &c.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return &c, err
}

func (r *ChatRepository) AddMember(ctx context.Context, chatID, userID uuid.UUID, role models.MemberRole) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO chat_members (chat_id, user_id, role)
		VALUES ($1, $2, $3)
		ON CONFLICT (chat_id, user_id) DO NOTHING`,
		chatID, userID, role,
	)
	return err
}

func (r *ChatRepository) RemoveMember(ctx context.Context, chatID, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM chat_members WHERE chat_id = $1 AND user_id = $2`,
		chatID, userID,
	)
	return err
}

func (r *ChatRepository) IsMember(ctx context.Context, chatID, userID uuid.UUID) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2)`,
		chatID, userID,
	).Scan(&exists)
	return exists, err
}

func (r *ChatRepository) GetMemberRole(ctx context.Context, chatID, userID uuid.UUID) (models.MemberRole, error) {
	var role models.MemberRole
	err := r.pool.QueryRow(ctx,
		`SELECT role FROM chat_members WHERE chat_id = $1 AND user_id = $2`,
		chatID, userID,
	).Scan(&role)
	return role, err
}

func (r *ChatRepository) GetMembers(ctx context.Context, chatID uuid.UUID) ([]models.ChatMember, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT cm.chat_id, cm.user_id, cm.joined_at, cm.role,
			u.id, u.phone, u.email, u.password_hash, u.name, u.surname, u.username,
			u.avatar_url, u.is_verified, u.created_at, u.updated_at
		FROM chat_members cm
		INNER JOIN users u ON u.id = cm.user_id
		WHERE cm.chat_id = $1
		ORDER BY cm.joined_at`,
		chatID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []models.ChatMember
	for rows.Next() {
		var m models.ChatMember
		var u models.User
		if err := rows.Scan(
			&m.ChatID, &m.UserID, &m.JoinedAt, &m.Role,
			&u.ID, &u.Phone, &u.Email, &u.PasswordHash, &u.Name, &u.Surname, &u.Username,
			&u.AvatarURL, &u.IsVerified, &u.CreatedAt, &u.UpdatedAt,
		); err != nil {
			return nil, err
		}
		m.User = &u
		members = append(members, m)
	}
	return members, rows.Err()
}

func (r *ChatRepository) GetMembersForChats(ctx context.Context, chatIDs []uuid.UUID) (map[uuid.UUID][]models.ChatMember, error) {
	result := make(map[uuid.UUID][]models.ChatMember)
	if len(chatIDs) == 0 {
		return result, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT cm.chat_id, cm.user_id, cm.joined_at, cm.role,
			u.id, u.phone, u.email, u.password_hash, u.name, u.surname, u.username,
			u.avatar_url, u.is_verified, u.created_at, u.updated_at
		FROM chat_members cm
		INNER JOIN users u ON u.id = cm.user_id
		WHERE cm.chat_id = ANY($1)
		ORDER BY cm.chat_id, cm.joined_at`,
		chatIDs,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var m models.ChatMember
		var u models.User
		if err := rows.Scan(
			&m.ChatID, &m.UserID, &m.JoinedAt, &m.Role,
			&u.ID, &u.Phone, &u.Email, &u.PasswordHash, &u.Name, &u.Surname, &u.Username,
			&u.AvatarURL, &u.IsVerified, &u.CreatedAt, &u.UpdatedAt,
		); err != nil {
			return nil, err
		}
		u.PasswordHash = ""
		m.User = &u
		result[m.ChatID] = append(result[m.ChatID], m)
	}
	return result, rows.Err()
}

func (r *ChatRepository) FindDirectChat(ctx context.Context, userA, userB uuid.UUID) (*models.Chat, error) {
	var c models.Chat
	err := r.pool.QueryRow(ctx, `
		SELECT c.id, c.type, c.name, c.avatar_url, c.created_by, c.created_at
		FROM chats c
		WHERE c.type = 'direct'
		AND EXISTS (SELECT 1 FROM chat_members m WHERE m.chat_id = c.id AND m.user_id = $1)
		AND EXISTS (SELECT 1 FROM chat_members m WHERE m.chat_id = c.id AND m.user_id = $2)
		AND (SELECT COUNT(*) FROM chat_members m WHERE m.chat_id = c.id) = 2
		LIMIT 1`,
		userA, userB,
	).Scan(&c.ID, &c.Type, &c.Name, &c.AvatarURL, &c.CreatedBy, &c.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return &c, err
}

func (r *ChatRepository) ListForUser(ctx context.Context, userID uuid.UUID) ([]models.ChatListItem, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT c.id, c.type, c.name, c.avatar_url, c.created_by, c.created_at,
			msg.id, msg.chat_id, msg.sender_id, msg.type, msg.content, msg.media_url,
			msg.duration_sec, msg.reply_to_id, msg.is_edited, msg.is_deleted, msg.created_at
		FROM chats c
		INNER JOIN chat_members cm ON cm.chat_id = c.id AND cm.user_id = $1
		LEFT JOIN LATERAL (
			SELECT * FROM messages
			WHERE chat_id = c.id AND is_deleted = FALSE
			ORDER BY created_at DESC, id DESC LIMIT 1
		) msg ON TRUE
		ORDER BY COALESCE(msg.created_at, c.created_at) DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []models.ChatListItem
	for rows.Next() {
		var item models.ChatListItem
		var (
			msgID, msgChatID, msgSenderID, replyToID *uuid.UUID
			msgType                                   *models.MessageType
			content, mediaURL                         *string
			durationSec                               *int
			isEdited, isDeleted                       *bool
			msgCreatedAt                              *time.Time
		)
		err := rows.Scan(
			&item.ID, &item.Type, &item.Name, &item.AvatarURL, &item.CreatedBy, &item.CreatedAt,
			&msgID, &msgChatID, &msgSenderID, &msgType, &content, &mediaURL, &durationSec,
			&replyToID, &isEdited, &isDeleted, &msgCreatedAt,
		)
		if err != nil {
			return nil, err
		}
		if msgID != nil {
			item.LastMessage = &models.Message{
				ID:          *msgID,
				ChatID:      *msgChatID,
				SenderID:    *msgSenderID,
				Type:        *msgType,
				Content:     content,
				MediaURL:    mediaURL,
				DurationSec: durationSec,
				ReplyToID:   replyToID,
				IsEdited:    *isEdited,
				IsDeleted:   *isDeleted,
				CreatedAt:   *msgCreatedAt,
			}
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *ChatRepository) MemberCount(ctx context.Context, chatID uuid.UUID) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM chat_members WHERE chat_id = $1`, chatID,
	).Scan(&count)
	return count, err
}
