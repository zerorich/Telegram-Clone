package utils

import (
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
)

// HashOTP returns a SHA-256 hex digest of code+pepper suitable for DB storage.
func HashOTP(code, pepper string) string {
	sum := sha256.Sum256([]byte(code + pepper))
	return hex.EncodeToString(sum[:])
}

// CompareOTP compares a plaintext code against a stored hash using constant-time compare.
func CompareOTP(code, pepper, storedHash string) bool {
	expected := HashOTP(code, pepper)
	return subtle.ConstantTimeCompare([]byte(expected), []byte(storedHash)) == 1
}
