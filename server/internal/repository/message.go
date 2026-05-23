package repository

import (
	"context"
	"errors"
	"fmt"
	"strings"

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

// messageColumns is the canonical column list for SELECTs against messages.
// Kept in one place so any new columns get picked up everywhere we Scan.
const messageColumns = `id, chat_id, sender_id, type, content, media_url, duration_sec,
	reply_to_id, is_edited, is_deleted, created_at,
	is_pinned, pinned_at, forwarded_from_user_id, forwarded_from_chat_id`

func scanMessage(row pgx.Row, m *models.Message) error {
	return row.Scan(
		&m.ID, &m.ChatID, &m.SenderID, &m.Type, &m.Content, &m.MediaURL, &m.DurationSec,
		&m.ReplyToID, &m.IsEdited, &m.IsDeleted, &m.CreatedAt,
		&m.IsPinned, &m.PinnedAt, &m.ForwardedFromUserID, &m.ForwardedFromChatID,
	)
}

func (r *MessageRepository) Create(ctx context.Context, msg *models.Message) error {
	return r.pool.QueryRow(ctx, `
		INSERT INTO messages (chat_id, sender_id, type, content, media_url, duration_sec,
			reply_to_id, forwarded_from_user_id, forwarded_from_chat_id)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, is_edited, is_deleted, created_at, is_pinned, pinned_at`,
		msg.ChatID, msg.SenderID, msg.Type, msg.Content, msg.MediaURL, msg.DurationSec,
		msg.ReplyToID, msg.ForwardedFromUserID, msg.ForwardedFromChatID,
	).Scan(&msg.ID, &msg.IsEdited, &msg.IsDeleted, &msg.CreatedAt, &msg.IsPinned, &msg.PinnedAt)
}

func (r *MessageRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Message, error) {
	var m models.Message
	row := r.pool.QueryRow(ctx, `SELECT `+messageColumns+` FROM messages WHERE id = $1`, id)
	if err := scanMessage(row, &m); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &m, nil
}

func (r *MessageRepository) List(ctx context.Context, chatID uuid.UUID, cursor *models.PaginationCursor, limit int) ([]models.Message, error) {
	var rows pgx.Rows
	var err error

	if cursor != nil {
		rows, err = r.pool.Query(ctx, `
			SELECT `+messageColumns+`
			FROM messages
			WHERE chat_id = $1 AND is_deleted = FALSE
			AND (created_at, id) < ($2, $3)
			ORDER BY created_at DESC, id DESC
			LIMIT $4`,
			chatID, cursor.CreatedAt, cursor.ID, limit,
		)
	} else {
		rows, err = r.pool.Query(ctx, `
			SELECT `+messageColumns+`
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
		if err := scanMessage(rows, &m); err != nil {
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
	row := r.pool.QueryRow(ctx, `
		UPDATE messages SET content = $1, is_edited = TRUE
		WHERE id = $2 AND sender_id = $3 AND type = 'text' AND is_deleted = FALSE
		RETURNING `+messageColumns,
		content, messageID, senderID,
	)
	if err := scanMessage(row, &m); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("message not found")
		}
		return nil, err
	}
	return &m, nil
}

func (r *MessageRepository) SoftDelete(ctx context.Context, messageID, senderID uuid.UUID) (*models.Message, error) {
	var m models.Message
	row := r.pool.QueryRow(ctx, `
		UPDATE messages SET is_deleted = TRUE
		WHERE id = $1 AND sender_id = $2 AND is_deleted = FALSE
		RETURNING `+messageColumns,
		messageID, senderID,
	)
	if err := scanMessage(row, &m); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("message not found")
		}
		return nil, err
	}
	return &m, nil
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

// Pin marks an existing message as pinned. Returns the refreshed Message row,
// or ErrNoRows when no message matches (caller should translate to 404).
func (r *MessageRepository) Pin(ctx context.Context, messageID, chatID uuid.UUID) (*models.Message, error) {
	var m models.Message
	row := r.pool.QueryRow(ctx, `
		UPDATE messages
		SET is_pinned = TRUE, pinned_at = NOW()
		WHERE id = $1 AND chat_id = $2 AND is_deleted = FALSE
		RETURNING `+messageColumns,
		messageID, chatID,
	)
	if err := scanMessage(row, &m); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("message not found")
		}
		return nil, err
	}
	return &m, nil
}

func (r *MessageRepository) Unpin(ctx context.Context, messageID, chatID uuid.UUID) (*models.Message, error) {
	var m models.Message
	row := r.pool.QueryRow(ctx, `
		UPDATE messages
		SET is_pinned = FALSE, pinned_at = NULL
		WHERE id = $1 AND chat_id = $2
		RETURNING `+messageColumns,
		messageID, chatID,
	)
	if err := scanMessage(row, &m); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("message not found")
		}
		return nil, err
	}
	return &m, nil
}

func (r *MessageRepository) ListPinned(ctx context.Context, chatID uuid.UUID, limit int) ([]models.Message, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	rows, err := r.pool.Query(ctx, `
		SELECT `+messageColumns+`
		FROM messages
		WHERE chat_id = $1 AND is_pinned = TRUE AND is_deleted = FALSE
		ORDER BY pinned_at DESC
		LIMIT $2`,
		chatID, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Message
	for rows.Next() {
		var m models.Message
		if err := scanMessage(rows, &m); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// Search performs a case-insensitive substring match against the `content`
// column. Empty queries return an empty slice; the caller is expected to clamp
// the limit but we also defend here.
func (r *MessageRepository) Search(ctx context.Context, chatID uuid.UUID, query string, limit int) ([]models.Message, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return []models.Message{}, nil
	}
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	pattern := "%" + query + "%"
	rows, err := r.pool.Query(ctx, `
		SELECT `+messageColumns+`
		FROM messages
		WHERE chat_id = $1 AND is_deleted = FALSE AND content ILIKE $2
		ORDER BY created_at DESC, id DESC
		LIMIT $3`,
		chatID, pattern, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Message
	for rows.Next() {
		var m models.Message
		if err := scanMessage(rows, &m); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// ClearChat deletes every message in a chat (including soft-deleted ones).
// CASCADE on message_reads/forwarded_* FKs is relied upon for cleanup.
func (r *MessageRepository) ClearChat(ctx context.Context, chatID uuid.UUID) (int64, error) {
	tag, err := r.pool.Exec(ctx, `DELETE FROM messages WHERE chat_id = $1`, chatID)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}
