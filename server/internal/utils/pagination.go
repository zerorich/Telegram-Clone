package utils

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/models"
)

type cursorPayload struct {
	CreatedAt time.Time `json:"created_at"`
	ID        uuid.UUID `json:"id"`
}

func EncodeCursor(c *models.PaginationCursor) string {
	if c == nil {
		return ""
	}
	p := cursorPayload{CreatedAt: c.CreatedAt, ID: c.ID}
	b, _ := json.Marshal(p)
	return base64.URLEncoding.EncodeToString(b)
}

func DecodeCursor(s string) (*models.PaginationCursor, error) {
	if s == "" {
		return nil, nil
	}
	b, err := base64.URLEncoding.DecodeString(s)
	if err != nil {
		return nil, fmt.Errorf("invalid cursor")
	}
	var p cursorPayload
	if err := json.Unmarshal(b, &p); err != nil {
		return nil, fmt.Errorf("invalid cursor")
	}
	return &models.PaginationCursor{CreatedAt: p.CreatedAt, ID: p.ID}, nil
}
