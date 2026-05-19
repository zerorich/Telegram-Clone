package middleware

import (
	"sync"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/telegramclone/server/internal/utils"
)

type ipEntry struct {
	count   int
	resetAt time.Time
}

type RateLimiter struct {
	mu      sync.Mutex
	entries map[string]*ipEntry
	limit   int
	window  time.Duration
}

func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{
		entries: make(map[string]*ipEntry),
		limit:   limit,
		window:  window,
	}
}

func (rl *RateLimiter) Middleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		ip := c.IP()
		now := time.Now()

		rl.mu.Lock()
		e, ok := rl.entries[ip]
		if !ok || now.After(e.resetAt) {
			rl.entries[ip] = &ipEntry{count: 1, resetAt: now.Add(rl.window)}
			rl.mu.Unlock()
			return c.Next()
		}
		e.count++
		if e.count > rl.limit {
			rl.mu.Unlock()
			return utils.Fail(c, fiber.StatusTooManyRequests, "rate limit exceeded")
		}
		rl.mu.Unlock()
		return c.Next()
	}
}
