package services

import (
	"context"
	"crypto/sha256"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
	"github.com/telegramclone/server/internal/models"
	"github.com/telegramclone/server/internal/repository"
	"github.com/telegramclone/server/internal/utils"
)

type AuthService struct {
	users            *repository.UserRepository
	otp              *repository.OTPRepository
	authRedis        *repository.AuthRedisRepository
	jwt              *utils.JWTManager
	email            *utils.EmailSender
	refreshTTL       time.Duration
	otpExpiry        time.Duration
	registrationTTL  time.Duration
	otpPepper        string
	otpMaxAttempts   int
	otpLockout       time.Duration
	devMode          bool
}

func NewAuthService(
	users *repository.UserRepository,
	otp *repository.OTPRepository,
	authRedis *repository.AuthRedisRepository,
	jwt *utils.JWTManager,
	email *utils.EmailSender,
	refreshTTL, otpExpiry, registrationTTL time.Duration,
	otpPepper string,
	otpMaxAttempts int,
	otpLockout time.Duration,
	devMode bool,
) *AuthService {
	return &AuthService{
		users: users, otp: otp, authRedis: authRedis,
		jwt: jwt, email: email, refreshTTL: refreshTTL,
		otpExpiry: otpExpiry, registrationTTL: registrationTTL,
		otpPepper: otpPepper, otpMaxAttempts: otpMaxAttempts,
		otpLockout: otpLockout, devMode: devMode,
	}
}

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

type VerifyCodeResult struct {
	IsNewUser         bool
	User              *models.User
	Tokens            *TokenPair
	RegistrationToken string
}

func (s *AuthService) SendCode(ctx context.Context, email string) error {
	if err := s.otp.InvalidateOld(ctx, email); err != nil {
		return err
	}
	code, err := utils.GenerateOTP()
	if err != nil {
		return err
	}
	expires := time.Now().Add(s.otpExpiry)
	codeHash := utils.HashOTP(code, s.otpPepper)
	if _, err := s.otp.Create(ctx, email, codeHash, expires); err != nil {
		return err
	}
	if err := s.email.SendOTP(email, code); err != nil {
		if s.devMode {
			log.Info().Str("email", email).Str("otp", code).Msg("dev mode: OTP (email send failed)")
			return nil
		}
		return ErrSendOTP
	}
	if s.devMode {
		log.Info().Str("email", email).Str("otp", code).Msg("dev mode: OTP sent")
	}
	return nil
}

func (s *AuthService) VerifyCode(ctx context.Context, email, code string) (*VerifyCodeResult, error) {
	locked, err := s.authRedis.IsOTPLocked(ctx, email)
	if err != nil {
		return nil, err
	}
	if locked {
		return nil, ErrOTPLocked
	}

	ok, err := s.otp.Verify(ctx, email, code, s.otpPepper)
	if err != nil {
		return nil, err
	}
	if !ok {
		if failErr := s.authRedis.RecordOTPFailure(ctx, email, s.otpMaxAttempts, s.otpLockout); failErr != nil {
			return nil, failErr
		}
		return nil, ErrInvalidOTP
	}
	_ = s.authRedis.ClearOTPFailures(ctx, email)

	user, err := s.users.GetByEmail(ctx, email)
	if err != nil {
		return nil, err
	}
	if user != nil {
		tokens, err := s.issueTokens(ctx, user.ID)
		if err != nil {
			return nil, err
		}
		return &VerifyCodeResult{IsNewUser: false, User: user, Tokens: tokens}, nil
	}

	if err := s.authRedis.MarkEmailVerified(ctx, email, s.registrationTTL); err != nil {
		return nil, err
	}
	regToken, err := s.jwt.GenerateRegistrationToken(email)
	if err != nil {
		return nil, err
	}
	return &VerifyCodeResult{IsNewUser: true, RegistrationToken: regToken}, nil
}

func (s *AuthService) CompleteProfile(ctx context.Context, registrationToken, email, name, phone string, surname *string) (*models.User, *TokenPair, error) {
	// 1. Validate registration token: signature, expiry, purpose, email-claim match.
	claims, err := s.jwt.ParseRegistrationToken(registrationToken)
	if err != nil || claims.Purpose != "registration" {
		return nil, nil, ErrInvalidRegistrationTok
	}
	if !strings.EqualFold(claims.Email, email) {
		return nil, nil, ErrInvalidRegistrationTok
	}
	// 2. Defense-in-depth: the Redis flag must also still be present.
	verified, err := s.authRedis.IsEmailVerified(ctx, email)
	if err != nil {
		return nil, nil, err
	}
	if !verified {
		return nil, nil, ErrNotVerified
	}
	existing, err := s.users.GetByEmail(ctx, email)
	if err != nil {
		return nil, nil, err
	}
	if existing != nil {
		return nil, nil, ErrAccountExists
	}
	if phone == "" {
		phone = placeholderPhone(email)
	}
	taken, err := s.users.ExistsByPhoneOrEmail(ctx, phone, email)
	if err != nil {
		return nil, nil, err
	}
	if taken {
		return nil, nil, ErrPhoneInUse
	}

	user := &models.User{
		Phone:        phone,
		Email:        email,
		PasswordHash: "",
		Name:         name,
		Surname:      surname,
		IsVerified:   true,
	}
	if err := s.users.Create(ctx, user); err != nil {
		return nil, nil, err
	}
	_ = s.authRedis.ClearRegistration(ctx, email)

	tokens, err := s.issueTokens(ctx, user.ID)
	if err != nil {
		return nil, nil, err
	}
	return user, tokens, nil
}

func placeholderPhone(email string) string {
	sum := sha256.Sum256([]byte(email))
	// Unique synthetic phone for email-only sign-up (fits VARCHAR(32)).
	return fmt.Sprintf("e%031x", sum)[:32]
}

func (s *AuthService) Refresh(ctx context.Context, refreshToken string) (*TokenPair, error) {
	claims, err := s.jwt.ParseToken(refreshToken)
	if err != nil || claims.TokenType != utils.TokenTypeRefresh {
		return nil, ErrInvalidRefreshToken
	}
	ok, err := s.authRedis.ValidateRefreshToken(ctx, claims.UserID, claims.ID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrRefreshTokenRevoked
	}
	_ = s.authRedis.RevokeRefreshToken(ctx, claims.UserID, claims.ID)
	return s.issueTokens(ctx, claims.UserID)
}

// Logout revokes the refresh token if valid AND blacklists the access token's
// jti for its remaining lifetime so it cannot be used after sign-out.
// Tokens without a jti (legacy) are skipped on the access-token side.
func (s *AuthService) Logout(ctx context.Context, refreshToken, accessToken string) error {
	if accessToken != "" {
		if accessClaims, err := s.jwt.ParseToken(accessToken); err == nil && accessClaims.TokenType == utils.TokenTypeAccess {
			if accessClaims.ID != "" && accessClaims.ExpiresAt != nil {
				ttl := time.Until(accessClaims.ExpiresAt.Time)
				if ttl > 0 {
					_ = s.authRedis.RevokeAccessToken(ctx, accessClaims.ID, ttl)
				}
			}
		}
	}
	if refreshToken == "" {
		return nil
	}
	claims, err := s.jwt.ParseToken(refreshToken)
	if err != nil {
		return nil
	}
	return s.authRedis.RevokeRefreshToken(ctx, claims.UserID, claims.ID)
}

func (s *AuthService) issueTokens(ctx context.Context, userID uuid.UUID) (*TokenPair, error) {
	access, err := s.jwt.GenerateAccessToken(userID)
	if err != nil {
		return nil, err
	}
	refresh, err := s.jwt.GenerateRefreshToken(userID)
	if err != nil {
		return nil, err
	}
	claims, err := s.jwt.ParseToken(refresh)
	if err != nil {
		return nil, err
	}
	if err := s.authRedis.StoreRefreshToken(ctx, userID, claims.ID, s.refreshTTL); err != nil {
		return nil, err
	}
	return &TokenPair{AccessToken: access, RefreshToken: refresh}, nil
}
