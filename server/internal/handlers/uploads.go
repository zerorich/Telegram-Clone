package handlers

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/telegramclone/server/internal/utils"
)

func Uploads(uploadDir string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		rel := c.Params("*")
		if rel == "" || strings.Contains(rel, "..") {
			return fiber.ErrNotFound
		}
		full := filepath.Join(uploadDir, filepath.FromSlash(rel))
		if _, err := os.Stat(full); err != nil {
			return fiber.ErrNotFound
		}
		mime := utils.MIMEFromFilename(full)
		if mime == "" {
			mime = "application/octet-stream"
		}
		c.Set("Content-Type", mime)
		c.Set("Accept-Ranges", "bytes")
		return c.SendFile(full)
	}
}
