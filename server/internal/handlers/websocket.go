package handlers

import (
	"context"
	"encoding/json"
	"strings"
	"time"

	"github.com/fasthttp/websocket"
	"github.com/gofiber/fiber/v2"
	fiberws "github.com/gofiber/contrib/websocket"
	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/repository"
	"github.com/telegramclone/server/internal/services"
	"github.com/telegramclone/server/internal/utils"
)

const (
	wsLocalsToken    = "ws_token"
	wsBearerProtocol = "bearer."
)

type WSHandler struct {
	jwt            *utils.JWTManager
	authRedis      *repository.AuthRedisRepository
	messages       *services.MessageService
	hub            *services.Hub
	allowedOrigins map[string]struct{}
	pingInterval   time.Duration
	readTimeout    time.Duration
}

// NewWSHandler builds the websocket handler. The allowedOrigins list is used to
// validate the Origin header on incoming upgrade requests (cross-cutting CSRF
// protection that mirrors the HTTP CORS policy).
func NewWSHandler(
	jwt *utils.JWTManager,
	authRedis *repository.AuthRedisRepository,
	messages *services.MessageService,
	hub *services.Hub,
	allowedOrigins []string,
	pingInterval, readTimeout time.Duration,
) *WSHandler {
	allowed := make(map[string]struct{}, len(allowedOrigins))
	for _, o := range allowedOrigins {
		o = strings.TrimSpace(o)
		if o != "" {
			allowed[o] = struct{}{}
		}
	}
	return &WSHandler{
		jwt: jwt, authRedis: authRedis, messages: messages, hub: hub,
		allowedOrigins: allowed, pingInterval: pingInterval, readTimeout: readTimeout,
	}
}

func (h *WSHandler) Upgrade(c *fiber.Ctx) error {
	origin := c.Get("Origin")
	if origin != "" {
		if _, ok := h.allowedOrigins[origin]; !ok {
			return fiber.NewError(fiber.StatusForbidden, "origin not allowed")
		}
	}

	token := c.Query("token")
	if token == "" {
		requested := c.Get("Sec-WebSocket-Protocol")
		for _, proto := range strings.Split(requested, ",") {
			proto = strings.TrimSpace(proto)
			if strings.HasPrefix(proto, wsBearerProtocol) {
				token = strings.TrimPrefix(proto, wsBearerProtocol)
				c.Set("Sec-WebSocket-Protocol", proto)
				break
			}
		}
	}

	if token == "" {
		return fiber.NewError(fiber.StatusUnauthorized, "token required")
	}

	claims, err := h.jwt.ParseToken(token)
	if err != nil || claims.TokenType != utils.TokenTypeAccess {
		return fiber.NewError(fiber.StatusUnauthorized, "invalid or expired token")
	}
	if h.authRedis != nil && claims.ID != "" {
		revoked, err := h.authRedis.IsAccessTokenRevoked(c.Context(), claims.ID)
		if err == nil && revoked {
			return fiber.NewError(fiber.StatusUnauthorized, "token revoked")
		}
	}

	c.Locals(wsLocalsToken, token)
	c.Locals("ws_user_id", claims.UserID)
	return c.Next()
}

func (h *WSHandler) Handle() func(*fiberws.Conn) {
	return func(c *fiberws.Conn) {
		userIDVal := c.Locals("ws_user_id")
		userID, ok := userIDVal.(uuid.UUID)
		if !ok || userID == uuid.Nil {
			_ = c.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.ClosePolicyViolation, "missing user context"))
			_ = c.Close()
			return
		}
		h.serveConn(userID, c)
	}
}

func (h *WSHandler) serveConn(userID uuid.UUID, conn *fiberws.Conn) {
	ctx := context.Background()
	done := make(chan struct{})
	defer close(done)

	client := services.NewWSClient(conn.Conn)
	h.hub.Register(userID, client)
	h.messages.BroadcastOnline(ctx, userID, true)
	defer func() {
		h.hub.Unregister(userID, client)
		h.messages.BroadcastOnline(ctx, userID, false)
		_ = conn.Close()
	}()

	conn.SetReadLimit(65536)
	_ = conn.SetReadDeadline(time.Now().Add(h.readTimeout))
	conn.SetPongHandler(func(string) error {
		return conn.SetReadDeadline(time.Now().Add(h.readTimeout))
	})

	go func() {
		ticker := time.NewTicker(h.pingInterval)
		defer ticker.Stop()
		for {
			select {
			case <-done:
				return
			case <-ticker.C:
				if err := client.Write(websocket.PingMessage, nil, 10*time.Second); err != nil {
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
			Type      string          `json:"type"`
			ChatID    uuid.UUID       `json:"chat_id"`
			Content   string          `json:"content"`
			ReplyToID *uuid.UUID      `json:"reply_to_id"`
			MessageID uuid.UUID       `json:"message_id"`
			CallID    uuid.UUID       `json:"callId"`
			FromUserID uuid.UUID      `json:"fromUserId"`
			ToUserID  uuid.UUID       `json:"toUserId"`
			SDP       string          `json:"sdp"`
			Media     string          `json:"media"`
			Candidate json.RawMessage `json:"candidate"`
			Reason    string          `json:"reason"`
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
		case "call.offer", "call.answer", "call.ice", "call.end", "call.ring":
			h.handleCallEvent(ctx, incoming.Type, userID, raw)
		}
	}
}
