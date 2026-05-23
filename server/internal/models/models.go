package models

import (
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID           uuid.UUID  `json:"id"`
	Phone        string     `json:"phone"`
	Email        string     `json:"email"`
	PasswordHash string     `json:"-"`
	Name         string     `json:"name"`
	Surname      *string    `json:"surname,omitempty"`
	Username     *string    `json:"username,omitempty"`
	AvatarURL    *string    `json:"avatar_url,omitempty"`
	IsVerified   bool       `json:"is_verified"`
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
}

type OTPCode struct {
	ID        uuid.UUID
	Email     string
	Code      string
	ExpiresAt time.Time
	Used      bool
}

type ChatType string

const (
	ChatTypeDirect ChatType = "direct"
	ChatTypeGroup  ChatType = "group"
	ChatTypeSaved  ChatType = "saved"
)

type MemberRole string

const (
	RoleMember MemberRole = "member"
	RoleAdmin  MemberRole = "admin"
	RoleOwner  MemberRole = "owner"
)

type Chat struct {
	ID         uuid.UUID  `json:"id"`
	Type       ChatType   `json:"type"`
	Name       *string    `json:"name,omitempty"`
	AvatarURL  *string    `json:"avatar_url,omitempty"`
	CreatedBy  *uuid.UUID `json:"created_by,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
}

type ChatMember struct {
	ChatID   uuid.UUID  `json:"chat_id"`
	UserID   uuid.UUID  `json:"user_id"`
	JoinedAt time.Time  `json:"joined_at"`
	Role     MemberRole `json:"role"`
	User     *User      `json:"user,omitempty"`
}

type MessageType string

const (
	MessageTypeText  MessageType = "text"
	MessageTypeImage MessageType = "image"
	MessageTypeVideo MessageType = "video"
	MessageTypeVoice MessageType = "voice"
	MessageTypeFile  MessageType = "file"
)

type Message struct {
	ID                  uuid.UUID   `json:"id"`
	ChatID              uuid.UUID   `json:"chat_id"`
	SenderID            uuid.UUID   `json:"sender_id"`
	Type                MessageType `json:"type"`
	Content             *string     `json:"content,omitempty"`
	MediaURL            *string     `json:"media_url,omitempty"`
	DurationSec         *int        `json:"duration_sec,omitempty"`
	ReplyToID           *uuid.UUID  `json:"reply_to_id,omitempty"`
	IsEdited            bool        `json:"is_edited"`
	IsDeleted           bool        `json:"is_deleted"`
	CreatedAt           time.Time   `json:"created_at"`
	IsPinned            bool        `json:"is_pinned"`
	PinnedAt            *time.Time  `json:"pinned_at,omitempty"`
	ForwardedFromUserID *uuid.UUID  `json:"forwarded_from_user_id,omitempty"`
	ForwardedFromChatID *uuid.UUID  `json:"forwarded_from_chat_id,omitempty"`
	ForwardedFromUser   *User       `json:"forwarded_from_user,omitempty"`
	IsRead              bool        `json:"is_read,omitempty"`
	Sender              *User       `json:"sender,omitempty"`
}

type ChatMute struct {
	UserID     uuid.UUID  `json:"user_id"`
	ChatID     uuid.UUID  `json:"chat_id"`
	MutedUntil *time.Time `json:"muted_until,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
}

type MessageRead struct {
	MessageID uuid.UUID `json:"message_id"`
	UserID    uuid.UUID `json:"user_id"`
	ReadAt    time.Time `json:"read_at"`
}

type ChatListItem struct {
	Chat
	LastMessage   *Message `json:"last_message,omitempty"`
	UnreadCount   int      `json:"unread_count"`
	Members       []ChatMember `json:"members,omitempty"`
}

type PaginationCursor struct {
	CreatedAt time.Time
	ID        uuid.UUID
}
