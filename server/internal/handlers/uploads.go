package handlers

import (
	"os"
	"path"
	"path/filepath"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/telegramclone/server/internal/utils"
)

// Uploads serves files under uploadDir. The route MUST be mounted behind JWT
// auth — see main.go where we register it on the protected group. Browsers
// can't attach `Authorization` to <img>/<video> tags, so callers either
// (a) use fetch() with the header, or (b) hit the same route on the protected
// group and pass `?t=<access_token>` which the route-level auth middleware
// promotes into an Authorization header before this handler runs.
//
// TODO(P1): add per-file membership check (which chat owns the file, is the
// caller still a member?). For now JWT presence is enough to keep media
// out of unauthenticated public crawlers.
func Uploads(uploadDir string) fiber.Handler {
	// Pre-clean the uploadDir once so the path-prefix check below is stable.
	cleanUploadDir := filepath.Clean(uploadDir)

	return func(c *fiber.Ctx) error {
		rel := c.Params("*")
		if rel == "" {
			return fiber.ErrNotFound
		}

		// Resolve the requested path against "/" so .. segments get folded
		// away. If anything remains that's traversal-shaped, reject.
		cleanRel := path.Clean("/" + rel)
		if strings.Contains(cleanRel, "..") {
			return fiber.ErrNotFound
		}

		full := filepath.Join(cleanUploadDir, filepath.FromSlash(cleanRel))
		// Defensive prefix check (handles symlink-escape edge cases).
		fullClean := filepath.Clean(full)
		if !strings.HasPrefix(fullClean, cleanUploadDir+string(os.PathSeparator)) && fullClean != cleanUploadDir {
			return fiber.ErrNotFound
		}

		fi, err := os.Stat(fullClean)
		if err != nil || fi.IsDir() {
			return fiber.ErrNotFound
		}

		mime := utils.MIMEFromFilename(fullClean)
		if mime == "" {
			mime = "application/octet-stream"
		}
		c.Set("Content-Type", mime)
		c.Set("Accept-Ranges", "bytes")
		// Private because the route is auth-gated; immutable because every
		// file is named after its content hash / UUID and never rewritten.
		c.Set("Cache-Control", "private, max-age=3600, immutable")
		return c.SendFile(fullClean)
	}
}
