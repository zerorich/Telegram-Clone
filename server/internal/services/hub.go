package services

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/fasthttp/websocket"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog/log"
)

const redisChannel = "ws:broadcast"

type Hub struct {
	rdb       *redis.Client
	clients   map[uuid.UUID]map[*websocket.Conn]struct{}
	mu        sync.RWMutex
	pubsub    *redis.PubSub
	instanceID string
}

type WSMessage struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data,omitempty"`
}

func NewHub(rdb *redis.Client) *Hub {
	return &Hub{
		rdb:        rdb,
		clients:    make(map[uuid.UUID]map[*websocket.Conn]struct{}),
		instanceID: uuid.New().String(),
	}
}

func (h *Hub) Start(ctx context.Context) error {
	h.pubsub = h.rdb.Subscribe(ctx, redisChannel)
	go h.listenRedis(ctx)
	return nil
}

func (h *Hub) Stop() {
	if h.pubsub != nil {
		_ = h.pubsub.Close()
	}
}

func (h *Hub) listenRedis(ctx context.Context) {
	ch := h.pubsub.Channel()
	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-ch:
			if !ok {
				return
			}
			var envelope struct {
				TargetUserIDs []uuid.UUID `json:"target_user_ids"`
				ExcludeConn   string      `json:"exclude_conn"`
				Payload       WSMessage   `json:"payload"`
			}
			if err := json.Unmarshal([]byte(msg.Payload), &envelope); err != nil {
				log.Error().Err(err).Msg("redis ws unmarshal")
				continue
			}
			h.deliverLocal(envelope.TargetUserIDs, envelope.Payload)
		}
	}
}

func (h *Hub) Register(userID uuid.UUID, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.clients[userID] == nil {
		h.clients[userID] = make(map[*websocket.Conn]struct{})
	}
	h.clients[userID][conn] = struct{}{}
}

func (h *Hub) Unregister(userID uuid.UUID, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if conns, ok := h.clients[userID]; ok {
		delete(conns, conn)
		if len(conns) == 0 {
			delete(h.clients, userID)
		}
	}
}

func (h *Hub) deliverLocal(userIDs []uuid.UUID, msg WSMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	h.mu.RLock()
	defer h.mu.RUnlock()
	for _, uid := range userIDs {
		for conn := range h.clients[uid] {
			_ = conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := conn.WriteMessage(websocket.TextMessage, data); err != nil {
				log.Debug().Err(err).Str("user_id", uid.String()).Msg("ws write failed")
			}
		}
	}
}

func (h *Hub) Broadcast(ctx context.Context, userIDs []uuid.UUID, msg WSMessage) {
	if len(userIDs) == 0 {
		return
	}
	envelope := struct {
		TargetUserIDs []uuid.UUID `json:"target_user_ids"`
		Payload       WSMessage   `json:"payload"`
	}{
		TargetUserIDs: userIDs,
		Payload:       msg,
	}
	b, err := json.Marshal(envelope)
	if err != nil {
		return
	}
	if err := h.rdb.Publish(ctx, redisChannel, b).Err(); err != nil {
		log.Error().Err(err).Msg("redis publish ws")
	}
}

func (h *Hub) OnlineUserIDs() []uuid.UUID {
	h.mu.RLock()
	defer h.mu.RUnlock()
	ids := make([]uuid.UUID, 0, len(h.clients))
	for id := range h.clients {
		ids = append(ids, id)
	}
	return ids
}

func (h *Hub) IsOnline(userID uuid.UUID) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	_, ok := h.clients[userID]
	return ok
}
