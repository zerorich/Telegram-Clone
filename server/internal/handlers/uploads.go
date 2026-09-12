package handlers

import (
	"os"
	"path"
	"path/filepath"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/telegramclone/server/internal/middleware"
	"github.com/telegramclone/server/internal/repository"
	"github.com/telegramclone/server/internal/utils"
)

// Uploads serves files under uploadDir. The route MUST be mounted behind JWT
// auth — see main.go where we register it on the protected group. Browsers
// can't attach `Authorization` to <img>/<video> tags, so callers either
// (a) use fetch() with the header, or (b) hit the same route on the protected
// group and pass `?t=<access_token>` which the route-level auth middleware
// promotes into an Authorization header before this handler runs.
func Uploads(uploadDir string, fileAccess *repository.FileAccessRepository) fiber.Handler {
	cleanUploadDir := filepath.Clean(uploadDir)

	return func(c *fiber.Ctx) error {
		rel := c.Params("*")
		if rel == "" {
			return fiber.ErrNotFound
		}

		cleanRel := path.Clean("/" + rel)
		if strings.Contains(cleanRel, "..") {
			return fiber.ErrNotFound
		}

		full := filepath.Join(cleanUploadDir, filepath.FromSlash(cleanRel))
		fullClean := filepath.Clean(full)
		if !strings.HasPrefix(fullClean, cleanUploadDir+string(os.PathSeparator)) && fullClean != cleanUploadDir {
			return fiber.ErrNotFound
		}

		fi, err := os.Stat(fullClean)
		if err != nil || fi.IsDir() {
			return fiber.ErrNotFound
		}

		userID, err := middleware.GetUserID(c)
		if err != nil {
			return utils.Fail(c, fiber.StatusUnauthorized, "unauthorized")
		}

		uploadPath := "/uploads/" + filepath.ToSlash(strings.TrimPrefix(cleanRel, "/"))
		allowed, err := fileAccess.CanAccessUpload(c.Context(), userID, uploadPath)
		if err != nil {
			return utils.Fail(c, fiber.StatusInternalServerError, "internal server error")
		}
		if !allowed {
			return utils.Fail(c, fiber.StatusForbidden, "access denied")
		}

		mime := utils.MIMEFromFilename(fullClean)
		if mime == "" {
			mime = "application/octet-stream"
		}
		c.Set("Content-Type", mime)
		c.Set("Accept-Ranges", "bytes")
		c.Set("Cache-Control", "private, max-age=3600, immutable")
		return c.SendFile(fullClean)
	}
}
