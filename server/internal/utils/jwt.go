package utils

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type TokenType string

const (
	TokenTypeAccess       TokenType = "access"
	TokenTypeRefresh      TokenType = "refresh"
	TokenTypeRegistration TokenType = "registration"
)

const (
	jwtIssuer   = "telegramclone"
	jwtAudience = "telegramclone-app"
	jwtLeeway   = 30 * time.Second
)

type Claims struct {
	UserID    uuid.UUID `json:"user_id"`
	TokenType TokenType `json:"token_type"`
	jwt.RegisteredClaims
}

type RegistrationClaims struct {
	Email   string `json:"email"`
	Purpose string `json:"purpose"`
	jwt.RegisteredClaims
}

type JWTManager struct {
	secret     []byte
	accessTTL  time.Duration
	refreshTTL time.Duration
}

func NewJWTManager(secret string, accessTTL, refreshTTL time.Duration) *JWTManager {
	return &JWTManager{
		secret:     []byte(secret),
		accessTTL:  accessTTL,
		refreshTTL: refreshTTL,
	}
}

func (m *JWTManager) GenerateAccessToken(userID uuid.UUID) (string, error) {
	return m.generateToken(userID, TokenTypeAccess, m.accessTTL)
}

func (m *JWTManager) GenerateRefreshToken(userID uuid.UUID) (string, error) {
	return m.generateToken(userID, TokenTypeRefresh, m.refreshTTL)
}

func (m *JWTManager) generateToken(userID uuid.UUID, tokenType TokenType, ttl time.Duration) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID:    userID,
		TokenType: tokenType,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    jwtIssuer,
			Audience:  jwt.ClaimStrings{jwtAudience},
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now),
			ID:        uuid.NewString(),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(m.secret)
}

// GenerateRegistrationToken issues a short-lived token used to authorize
// the complete-profile call for a freshly-verified email. The claims carry
// the email and a fixed purpose so the access-token path can never be used
// to bypass profile creation (and vice versa).
func (m *JWTManager) GenerateRegistrationToken(email string) (string, error) {
	now := time.Now()
	claims := RegistrationClaims{
		Email:   email,
		Purpose: "registration",
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    jwtIssuer,
			Audience:  jwt.ClaimStrings{jwtAudience},
			ExpiresAt: jwt.NewNumericDate(now.Add(30 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now),
			ID:        uuid.NewString(),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(m.secret)
}

func (m *JWTManager) ParseToken(tokenStr string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(
		tokenStr,
		&Claims{},
		func(t *jwt.Token) (interface{}, error) { return m.secret, nil },
		jwt.WithValidMethods([]string{"HS256"}),
		jwt.WithLeeway(jwtLeeway),
		jwt.WithIssuer(jwtIssuer),
		jwt.WithAudience(jwtAudience),
	)
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid token")
	}
	return claims, nil
}

func (m *JWTManager) ParseRegistrationToken(tokenStr string) (*RegistrationClaims, error) {
	token, err := jwt.ParseWithClaims(
		tokenStr,
		&RegistrationClaims{},
		func(t *jwt.Token) (interface{}, error) { return m.secret, nil },
		jwt.WithValidMethods([]string{"HS256"}),
		jwt.WithLeeway(jwtLeeway),
		jwt.WithIssuer(jwtIssuer),
		jwt.WithAudience(jwtAudience),
	)
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*RegistrationClaims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid registration token")
	}
	if claims.Purpose != "registration" {
		return nil, errors.New("invalid registration token purpose")
	}
	return claims, nil
}
