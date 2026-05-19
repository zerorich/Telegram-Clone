package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/telegramclone/server/internal/models"
)
	
type MessageRepository struct {
	pool *pgxpool.Pool
}

func NewMessageRepository(pool *pgxpool.Pool) *MessageRepository {
	return &MessageRepository{pool: pool}
}

func (r *MessageRepository) Create(ctx context.Context, msg *models.Message) error {
	return r.pool.QueryRow(ctx, `
		INSERT INTO messages (chat_id, sender_id, type, content, media_url, duration_sec, reply_to_id)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, is_edited, is_deleted, created_at`,
		msg.ChatID, msg.SenderID, msg.Type, msg.Content, msg.MediaURL, msg.DurationSec, msg.ReplyToID,
	).Scan(&msg.ID, &msg.IsEdited, &msg.IsDeleted, &msg.CreatedAt)
}

func (r *MessageRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Message, error) {
	var m models.Message
	err := r.pool.QueryRow(ctx, `
		SELECT id, chat_id, sender_id, type, content, media_url, duration_sec,
			reply_to_id, is_edited, is_deleted, created_at
		FROM messages WHERE id = $1`, id,
	).Scan(
		&m.ID, &m.ChatID, &m.SenderID, &m.Type, &m.Content, &m.MediaURL, &m.DurationSec,
		&m.ReplyToID, &m.IsEdited, &m.IsDeleted, &m.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return &m, err
}

func (r *MessageRepository) List(ctx context.Context, chatID uuid.UUID, cursor *models.PaginationCursor, limit int) ([]models.Message, error) {
	var rows pgx.Rows
	var err error

	if cursor != nil {
		rows, err = r.pool.Query(ctx, `
			SELECT id, chat_id, sender_id, type, content, media_url, duration_sec,
				reply_to_id, is_edited, is_deleted, created_at
			FROM messages
			WHERE chat_id = $1 AND is_deleted = FALSE
			AND (created_at, id) < ($2, $3)
			ORDER BY created_at DESC, id DESC
			LIMIT $4`,
			chatID, cursor.CreatedAt, cursor.ID, limit,
		)
	} else {
		rows, err = r.pool.Query(ctx, `
			SELECT id, chat_id, sender_id, type, content, media_url, duration_sec,
				reply_to_id, is_edited, is_deleted, created_at
			FROM messages
			WHERE chat_id = $1 AND is_deleted = FALSE
			ORDER BY created_at DESC, id DESC
			LIMIT $2`,
			chatID, limit,
		)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []models.Message
	for rows.Next() {
		var m models.Message
		if err := rows.Scan(
			&m.ID, &m.ChatID, &m.SenderID, &m.Type, &m.Content, &m.MediaURL, &m.DurationSec,
			&m.ReplyToID, &m.IsEdited, &m.IsDeleted, &m.CreatedAt,
		); err != nil {
			return nil, err
		}
		messages = append(messages, m)
	}
	return messages, rows.Err()
}

func (r *MessageRepository) IsReadByOthers(ctx context.Context, messageID, chatID, senderID uuid.UUID) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM message_reads r
			INNER JOIN chat_members cm ON cm.user_id = r.user_id AND cm.chat_id = $2
			WHERE r.message_id = $1 AND r.user_id != $3
		)`,
		messageID, chatID, senderID,
	).Scan(&exists)
	return exists, err
}

func (r *MessageRepository) MarkReadUpTo(ctx context.Context, chatID, userID, messageID uuid.UUID) (int64, error) {
	tag, err := r.pool.Exec(ctx, `
		INSERT INTO message_reads (message_id, user_id)
		SELECT m.id, $2
		FROM messages m
		WHERE m.chat_id = $1
		AND m.is_deleted = FALSE
		AND m.sender_id != $2
		AND (m.created_at, m.id) <= (
			SELECT created_at, id FROM messages WHERE id = $3
		)
		ON CONFLICT (message_id, user_id) DO NOTHING`,
		chatID, userID, messageID,
	)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

func (r *MessageRepository) GetReadReceipt(ctx context.Context, messageID, userID uuid.UUID) (*models.MessageRead, error) {
	var mr models.MessageRead
	err := r.pool.QueryRow(ctx, `
		SELECT message_id, user_id, read_at FROM message_reads
		WHERE message_id = $1 AND user_id = $2`,
		messageID, userID,
	).Scan(&mr.MessageID, &mr.UserID, &mr.ReadAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return &mr, err
}

func (r *MessageRepository) BelongsToChat(ctx context.Context, messageID, chatID uuid.UUID) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM messages WHERE id = $1 AND chat_id = $2)`,
		messageID, chatID,
	).Scan(&exists)
	return exists, err
}

func (r *MessageRepository) UnreadCount(ctx context.Context, chatID, userID uuid.UUID) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM messages m
		WHERE m.chat_id = $1 AND m.sender_id != $2 AND m.is_deleted = FALSE
		AND NOT EXISTS (
			SELECT 1 FROM message_reads r WHERE r.message_id = m.id AND r.user_id = $2
		)`,
		chatID, userID,
	).Scan(&count)
	return count, err
}

func (r *MessageRepository) UpdateText(ctx context.Context, messageID, senderID uuid.UUID, content string) (*models.Message, error) {
	var m models.Message
	err := r.pool.QueryRow(ctx, `
		UPDATE messages SET content = $1, is_edited = TRUE
		WHERE id = $2 AND sender_id = $3 AND type = 'text' AND is_deleted = FALSE
		RETURNING id, chat_id, sender_id, type, content, media_url, duration_sec,
			reply_to_id, is_edited, is_deleted, created_at`,
		content, messageID, senderID,
	).Scan(
		&m.ID, &m.ChatID, &m.SenderID, &m.Type, &m.Content, &m.MediaURL, &m.DurationSec,
		&m.ReplyToID, &m.IsEdited, &m.IsDeleted, &m.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, errors.New("message not found")
	}
	return &m, err
}

func (r *MessageRepository) SoftDelete(ctx context.Context, messageID, senderID uuid.UUID) (*models.Message, error) {
	var m models.Message
	err := r.pool.QueryRow(ctx, `
		UPDATE messages SET is_deleted = TRUE
		WHERE id = $1 AND sender_id = $2 AND is_deleted = FALSE
		RETURNING id, chat_id, sender_id, type, content, media_url, duration_sec,
			reply_to_id, is_edited, is_deleted, created_at`,
		messageID, senderID,
	).Scan(
		&m.ID, &m.ChatID, &m.SenderID, &m.Type, &m.Content, &m.MediaURL, &m.DurationSec,
		&m.ReplyToID, &m.IsEdited, &m.IsDeleted, &m.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, errors.New("message not found")
	}
	return &m, err
}

func (r *MessageRepository) ValidateReplyInChat(ctx context.Context, replyID, chatID uuid.UUID) error {
	var exists bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM messages WHERE id = $1 AND chat_id = $2)`,
		replyID, chatID,
	).Scan(&exists)
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("reply message not found in chat")
	}
	return nil
}
