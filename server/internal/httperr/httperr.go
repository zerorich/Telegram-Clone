package httperr

import (
	"errors"

	"github.com/gofiber/fiber/v2"
	"github.com/telegramclone/server/internal/services"
	"github.com/telegramclone/server/internal/utils"
)

// Map converts a domain or internal error into an HTTP status and a safe client message.
func Map(err error) (int, string) {
	if err == nil {
		return fiber.StatusInternalServerError, "internal server error"
	}

	switch {
	case errors.Is(err, services.ErrNotMember):
		return fiber.StatusForbidden, "not a chat member"
	case errors.Is(err, services.ErrForbidden):
		return fiber.StatusForbidden, "forbidden"
	case errors.Is(err, services.ErrChatNotFound):
		return fiber.StatusNotFound, "chat not found"
	case errors.Is(err, services.ErrNotVerified):
		return fiber.StatusBadRequest, "email not verified"
	case errors.Is(err, services.ErrInvalidRegistrationTok):
		return fiber.StatusUnauthorized, "registration token invalid or expired"
	case errors.Is(err, services.ErrInvalidOTP):
		return fiber.StatusBadRequest, "invalid or expired OTP"
	case errors.Is(err, services.ErrOTPLocked):
		return fiber.StatusTooManyRequests, "too many failed attempts; try again later"
	case errors.Is(err, services.ErrInvalidRefreshToken):
		return fiber.StatusUnauthorized, "invalid refresh token"
	case errors.Is(err, services.ErrRefreshTokenRevoked):
		return fiber.StatusUnauthorized, "refresh token revoked"
	case errors.Is(err, services.ErrAccountExists):
		return fiber.StatusBadRequest, "account already exists"
	case errors.Is(err, services.ErrPhoneInUse):
		return fiber.StatusBadRequest, "phone already in use"
	case errors.Is(err, services.ErrCannotDeleteSaved):
		return fiber.StatusBadRequest, "cannot delete saved messages chat"
	case errors.Is(err, services.ErrCannotChatSelf):
		return fiber.StatusBadRequest, "cannot chat with yourself"
	case errors.Is(err, services.ErrMessageNotFound):
		return fiber.StatusBadRequest, "message not found"
	case errors.Is(err, services.ErrSourceMessageNotFound):
		return fiber.StatusBadRequest, "source message not found"
	case errors.Is(err, services.ErrCannotForwardDeleted):
		return fiber.StatusBadRequest, "cannot forward a deleted message"
	case errors.Is(err, services.ErrInvalidMessageType):
		return fiber.StatusBadRequest, "invalid message type"
	case errors.Is(err, services.ErrFileTooLarge):
		return fiber.StatusBadRequest, "file too large"
	case errors.Is(err, services.ErrUnsupportedFileType):
		return fiber.StatusBadRequest, "unsupported file type"
	case errors.Is(err, services.ErrUsernameTaken):
		return fiber.StatusBadRequest, "username already taken"
	case errors.Is(err, services.ErrInvalidCursor):
		return fiber.StatusBadRequest, "invalid cursor"
	case errors.Is(err, services.ErrUserNotFound):
		return fiber.StatusNotFound, "user not found"
	case errors.Is(err, services.ErrFileAccessDenied):
		return fiber.StatusForbidden, "access denied"
	case errors.Is(err, services.ErrSendOTP):
		return fiber.StatusInternalServerError, "failed to send verification code"
	}

	if msg, ok := safeValidationMessage(err); ok {
		return fiber.StatusBadRequest, msg
	}

	return fiber.StatusInternalServerError, "internal server error"
}

func safeValidationMessage(err error) (string, bool) {
	switch {
	case errors.Is(err, utils.ErrFileTooLarge):
		return "file too large", true
	case errors.Is(err, utils.ErrUnsupportedMIME):
		return "unsupported file type", true
	case errors.Is(err, utils.ErrInvalidAvatar):
		return "avatar must be JPEG or PNG", true
	case errors.Is(err, utils.ErrAvatarTooLarge):
		return "avatar too large", true
	}
	msg := err.Error()
	if msg == "invalid cursor" {
		return "invalid cursor", true
	}
	if msg == "one or more users not found" {
		return "one or more users not found", true
	}
	if msg == "unsupported chat type" {
		return "unsupported chat type", true
	}
	return "", false
}

// Respond writes a JSON error response for err using Map.
func Respond(c *fiber.Ctx, err error) error {
	status, msg := Map(err)
	return utils.Fail(c, status, msg)
}

// RespondStatus allows overriding the status while still using safe messages.
func RespondStatus(c *fiber.Ctx, status int, err error) error {
	_, msg := Map(err)
	if status >= 500 {
		msg = "internal server error"
	}
	return utils.Fail(c, status, msg)
}

// BadRequest is a helper for explicit client errors without leaking internals.
func BadRequest(c *fiber.Ctx, message string) error {
	return utils.Fail(c, fiber.StatusBadRequest, message)
}

// Internal wraps an unexpected error while returning a safe response.
func Internal(c *fiber.Ctx, err error) error {
	return utils.Fail(c, fiber.StatusInternalServerError, "internal server error")
}
