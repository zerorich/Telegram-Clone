package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type FileAccessRepository struct {
	pool *pgxpool.Pool
}

func NewFileAccessRepository(pool *pgxpool.Pool) *FileAccessRepository {
	return &FileAccessRepository{pool: pool}
}

// CanAccessUpload returns true when the user owns the file (avatar) or is a
// member of a chat that references it via avatar_url or message media_url.
func (r *FileAccessRepository) CanAccessUpload(ctx context.Context, userID uuid.UUID, uploadPath string) (bool, error) {
	var allowed bool
	err := r.pool.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT 1 FROM users WHERE id = $1 AND avatar_url = $2
		) OR EXISTS (
			SELECT 1 FROM chats c
			JOIN chat_members cm ON cm.chat_id = c.id
			WHERE cm.user_id = $1 AND c.avatar_url = $2
		) OR EXISTS (
			SELECT 1 FROM messages m
			JOIN chat_members cm ON cm.chat_id = m.chat_id
			WHERE cm.user_id = $1 AND m.media_url = $2 AND m.is_deleted = FALSE
		)`,
		userID, uploadPath,
	).Scan(&allowed)
	return allowed, err
}
