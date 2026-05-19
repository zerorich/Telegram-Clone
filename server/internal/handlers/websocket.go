package handlers

import (
	"context"
	"encoding/json"
	"time"

	"github.com/fasthttp/websocket"
	fiberws "github.com/gofiber/contrib/websocket"
	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/services"
	"github.com/telegramclone/server/internal/utils"
)

type WSHandler struct {
	jwt      *utils.JWTManager
	messages *services.MessageService
	hub      *services.Hub
}

func NewWSHandler(jwt *utils.JWTManager, messages *services.MessageService, hub *services.Hub) *WSHandler {
	return &WSHandler{jwt: jwt, messages: messages, hub: hub}
}

func (h *WSHandler) Handle() func(*fiberws.Conn) {
	return func(c *fiberws.Conn) {
		token := c.Query("token")
		if token == "" {
			_ = c.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.ClosePolicyViolation, "token required"))
			_ = c.Close()
			return
		}
		claims, err := h.jwt.ParseToken(token)
		if err != nil || claims.TokenType != utils.TokenTypeAccess {
			_ = c.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.ClosePolicyViolation, "invalid token"))
			_ = c.Close()
			return
		}

		h.serveConn(claims.UserID, c)
	}
}

func (h *WSHandler) serveConn(userID uuid.UUID, conn *fiberws.Conn) {
	ctx := context.Background()
	done := make(chan struct{})
	defer close(done)

	h.hub.Register(userID, conn.Conn)
	h.messages.BroadcastOnline(ctx, userID, true)
	defer func() {
		h.hub.Unregister(userID, conn.Conn)
		h.messages.BroadcastOnline(ctx, userID, false)
		_ = conn.Close()
	}()

	conn.SetReadLimit(65536)
	_ = conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	conn.SetPongHandler(func(string) error {
		return conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	})

	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-done:
				return
			case <-ticker.C:
				_ = conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
				if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
					return
				}
			}
		}
	}()

	for {
		_, raw, err := conn.ReadMessage()
		if err != nil {
			break
		}
		var incoming struct {
			Type      string     `json:"type"`
			ChatID    uuid.UUID  `json:"chat_id"`
			Content   string     `json:"content"`
			ReplyToID *uuid.UUID `json:"reply_to_id"`
			MessageID uuid.UUID  `json:"message_id"`
		}
		if err := json.Unmarshal(raw, &incoming); err != nil {
			continue
		}
		switch incoming.Type {
		case "message.send":
			var replyTo *uuid.UUID
			if incoming.ReplyToID != nil && *incoming.ReplyToID != uuid.Nil {
				replyTo = incoming.ReplyToID
			}
			_, _ = h.messages.SendText(ctx, incoming.ChatID, userID, incoming.Content, replyTo)
		case "message.read":
			_ = h.messages.MarkRead(ctx, incoming.ChatID, userID, incoming.MessageID)
		case "typing.start":
			h.messages.BroadcastTyping(ctx, incoming.ChatID, userID, true)
		case "typing.stop":
			h.messages.BroadcastTyping(ctx, incoming.ChatID, userID, false)
		}
	}
}
