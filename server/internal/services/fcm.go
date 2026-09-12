package services

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/rs/zerolog/log"
)

const fcmLegacyEndpoint = "https://fcm.googleapis.com/fcm/send"

// FCMSender delivers data+notification payloads to device tokens via the
// legacy FCM HTTP API. Disabled when ServerKey is empty.
type FCMSender struct {
	ServerKey string
	client    *http.Client
}

func NewFCMSender(serverKey string) *FCMSender {
	return &FCMSender{
		ServerKey: serverKey,
		client:    &http.Client{Timeout: 8 * time.Second},
	}
}

func (s *FCMSender) Enabled() bool {
	return s != nil && s.ServerKey != ""
}

type fcmPayload struct {
	To           string            `json:"to"`
	Priority     string            `json:"priority"`
	Notification map[string]string `json:"notification"`
	Data         map[string]string `json:"data"`
}

func (s *FCMSender) NotifyNewMessage(ctx context.Context, tokens []string, title, body, chatID, messageID string) {
	if !s.Enabled() || len(tokens) == 0 {
		return
	}
	for _, token := range tokens {
		if token == "" {
			continue
		}
		payload := fcmPayload{
			To:       token,
			Priority: "high",
			Notification: map[string]string{
				"title": title,
				"body":  body,
			},
			Data: map[string]string{
				"chat_id":    chatID,
				"message_id": messageID,
				"title":      title,
				"body":       body,
			},
		}
		raw, err := json.Marshal(payload)
		if err != nil {
			continue
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, fcmLegacyEndpoint, bytes.NewReader(raw))
		if err != nil {
			continue
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "key="+s.ServerKey)
		resp, err := s.client.Do(req)
		if err != nil {
			log.Warn().Err(err).Msg("fcm send")
			continue
		}
		_ = resp.Body.Close()
		if resp.StatusCode >= 300 {
			log.Warn().Int("status", resp.StatusCode).Msg("fcm send rejected")
		}
	}
}
