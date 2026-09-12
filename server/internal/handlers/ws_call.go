package handlers

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"
	"github.com/telegramclone/server/internal/services"
)

type callPayload struct {
	CallID     uuid.UUID       `json:"callId"`
	FromUserID uuid.UUID       `json:"fromUserId"`
	ToUserID   uuid.UUID       `json:"toUserId"`
	SDP        string          `json:"sdp,omitempty"`
	Media      string          `json:"media,omitempty"`
	Candidate  json.RawMessage `json:"candidate,omitempty"`
	Reason     string          `json:"reason,omitempty"`
}

func (h *WSHandler) handleCallEvent(ctx context.Context, eventType string, userID uuid.UUID, raw []byte) {
	var p callPayload
	if err := json.Unmarshal(raw, &p); err != nil {
		return
	}
	if p.FromUserID != userID {
		h.sendCallError(ctx, userID, p.CallID, "fromUserId must match authenticated user")
		return
	}
	if p.ToUserID == uuid.Nil || p.CallID == uuid.Nil {
		h.sendCallError(ctx, userID, p.CallID, "callId and toUserId are required")
		return
	}

	if !h.hub.IsOnline(p.ToUserID) {
		endData, _ := json.Marshal(map[string]interface{}{
			"callId":     p.CallID,
			"fromUserId": userID,
			"toUserId":   p.ToUserID,
			"reason":     "callee_offline",
		})
		h.hub.SendToUser(ctx, userID, services.WSMessage{Type: "call.end", Data: endData})
		return
	}

	relayData, _ := json.Marshal(p)
	h.hub.SendToUser(ctx, p.ToUserID, services.WSMessage{Type: eventType, Data: relayData})

	if eventType == "call.offer" {
		ringData, _ := json.Marshal(map[string]interface{}{
			"callId":     p.CallID,
			"fromUserId": userID,
			"toUserId":   p.ToUserID,
			"media":      p.Media,
		})
		h.hub.SendToUser(ctx, p.ToUserID, services.WSMessage{Type: "call.ring", Data: ringData})
	}
}

func (h *WSHandler) sendCallError(ctx context.Context, userID, callID uuid.UUID, reason string) {
	data, _ := json.Marshal(map[string]interface{}{
		"callId": callID,
		"error":  reason,
	})
	h.hub.SendToUser(ctx, userID, services.WSMessage{Type: "call.error", Data: data})
}
