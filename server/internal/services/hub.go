package services

import (
	"context"
	"encoding/json"
	"sync"
	"time"

	"github.com/fasthttp/websocket"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog/log"
)

const redisChannel = "ws:broadcast"

// WSClient wraps a websocket.Conn with a per-connection write mutex.
// fasthttp/websocket (like gorilla) does NOT serialize writes per connection,
// so any goroutine writing to the same conn (e.g. ping ticker + hub broadcast)
// must hold writeMu before touching SetWriteDeadline / WriteMessage.
type WSClient struct {
	Conn    *websocket.Conn
	writeMu sync.Mutex
}

// NewWSClient creates a new client wrapper for the given connection.
func NewWSClient(conn *websocket.Conn) *WSClient {
	return &WSClient{Conn: conn}
}

// Write sends a websocket message while holding the per-connection write lock.
func (c *WSClient) Write(messageType int, data []byte, deadline time.Duration) error {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_ = c.Conn.SetWriteDeadline(time.Now().Add(deadline))
	return c.Conn.WriteMessage(messageType, data)
}

type Hub struct {
	rdb        *redis.Client
	clients    map[uuid.UUID]map[*WSClient]struct{}
	mu         sync.RWMutex
	pubsub     *redis.PubSub
	instanceID string
}

type WSMessage struct {
	Type string          `json:"type"`
	Data json.RawMessage `json:"data,omitempty"`
}

func NewHub(rdb *redis.Client) *Hub {
	return &Hub{
		rdb:        rdb,
		clients:    make(map[uuid.UUID]map[*WSClient]struct{}),
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

func (h *Hub) Register(userID uuid.UUID, client *WSClient) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.clients[userID] == nil {
		h.clients[userID] = make(map[*WSClient]struct{})
	}
	h.clients[userID][client] = struct{}{}
}

func (h *Hub) Unregister(userID uuid.UUID, client *WSClient) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if conns, ok := h.clients[userID]; ok {
		delete(conns, client)
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
	// Snapshot target clients under RLock, then release the lock before
	// performing any blocking writes; each client's writeMu serializes writes.
	targets := make([]*WSClient, 0, 8)
	h.mu.RLock()
	for _, uid := range userIDs {
		for c := range h.clients[uid] {
			targets = append(targets, c)
		}
	}
	h.mu.RUnlock()
	for _, c := range targets {
		if err := c.Write(websocket.TextMessage, data, 10*time.Second); err != nil {
			log.Debug().Err(err).Msg("ws write failed")
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

func (h *Hub) SendToUser(ctx context.Context, userID uuid.UUID, msg WSMessage) {
	h.Broadcast(ctx, []uuid.UUID{userID}, msg)
}
