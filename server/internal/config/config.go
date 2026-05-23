package config

import (
	"errors"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
	"github.com/rs/zerolog/log"
)

const defaultJWTSecret = "dev-secret-change-in-production"

type Config struct {
	Port           string
	Env            string
	DatabaseURL    string
	RedisAddr      string
	RedisPassword  string
	RedisTLS       bool
	RedisDB        int
	JWTSecret      string
	JWTAccessTTL   time.Duration
	JWTRefreshTTL  time.Duration
	SMTPHost       string
	SMTPPort       string
	SMTPUser       string
	SMTPPassword   string
	SMTPFrom       string
	UploadDir      string
	BaseURL        string
	CORSOrigins    []string
	AuthRateLimit  int
	AuthRateWindow time.Duration
	MigrationsDir  string
	DBMaxConns     int
}

func Load() (*Config, error) {
	_ = godotenv.Load()

	env := getEnv("ENV", "development")
	rawJWT := os.Getenv("JWT_SECRET")

	cfg := &Config{
		Port:          getEnv("PORT", "8080"),
		Env:           env,
		DatabaseURL:   getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/telegramclone?sslmode=disable"),
		RedisAddr:     getEnv("REDIS_ADDR", "localhost:6379"),
		RedisPassword: getEnv("REDIS_PASSWORD", ""),
		RedisTLS:      strings.EqualFold(getEnv("REDIS_TLS", "false"), "true"),
		RedisDB:       getEnvInt("REDIS_DB", 0),
		SMTPHost:      getEnv("SMTP_HOST", "localhost"),
		SMTPPort:      getEnv("SMTP_PORT", "587"),
		SMTPUser:      getEnv("SMTP_USER", ""),
		SMTPPassword:  getEnv("SMTP_PASSWORD", ""),
		SMTPFrom:      getEnv("SMTP_FROM", "noreply@telegramclone.local"),
		UploadDir:     getEnv("UPLOAD_DIR", "./uploads"),
		BaseURL:       getEnv("BASE_URL", "http://localhost:8080"),
		AuthRateLimit: getEnvInt("AUTH_RATE_LIMIT", 5),
		MigrationsDir: getEnv("MIGRATIONS_DIR", ""),
		DBMaxConns:    getEnvInt("DB_MAX_CONNS", 20),
	}

	// JWT secret: in production we refuse to start with the dev default.
	// In dev we allow the fallback but emit a loud warning so it's not silent.
	if env == "production" {
		if rawJWT == "" || rawJWT == defaultJWTSecret {
			return nil, errors.New("JWT_SECRET must be set to a strong secret in production (got empty or default dev value)")
		}
		cfg.JWTSecret = rawJWT
	} else {
		if rawJWT == "" {
			log.Warn().Msg("JWT_SECRET not set; using insecure dev fallback. DO NOT use in production.")
			cfg.JWTSecret = defaultJWTSecret
		} else {
			cfg.JWTSecret = rawJWT
		}
	}

	var err error
	cfg.JWTAccessTTL, err = time.ParseDuration(getEnv("JWT_ACCESS_TTL", "15m"))
	if err != nil {
		return nil, err
	}
	cfg.JWTRefreshTTL, err = time.ParseDuration(getEnv("JWT_REFRESH_TTL", "720h"))
	if err != nil {
		return nil, err
	}
	cfg.AuthRateWindow, err = time.ParseDuration(getEnv("AUTH_RATE_WINDOW", "1m"))
	if err != nil {
		return nil, err
	}

	origins := getEnv("CORS_ORIGINS", "http://localhost:3000,http://localhost:5173")
	cfg.CORSOrigins = strings.Split(origins, ",")
	for i := range cfg.CORSOrigins {
		cfg.CORSOrigins[i] = strings.TrimSpace(cfg.CORSOrigins[i])
	}

	return cfg, nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}
