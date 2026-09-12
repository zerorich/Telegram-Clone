package main

import (
	"context"
	"errors"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/gofiber/contrib/websocket"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
	"github.com/telegramclone/server/internal/config"
	"github.com/telegramclone/server/internal/database"
	"github.com/telegramclone/server/internal/handlers"
	"github.com/telegramclone/server/internal/middleware"
	"github.com/telegramclone/server/internal/repository"
	"github.com/telegramclone/server/internal/services"
	"github.com/telegramclone/server/internal/utils"
)

func main() {
	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr})

	cfg, err := config.Load()
	if err != nil {
		log.Fatal().Err(err).Msg("load config")
	}

	for _, o := range cfg.CORSOrigins {
		if o == "*" {
			log.Fatal().Msg("CORS_ORIGINS contains '*' but CORS is configured with AllowCredentials=true; this combination is rejected by browsers and is unsafe")
		}
	}

	ctx := context.Background()

	pool, err := database.NewPostgres(ctx, cfg.DatabaseURL, database.PoolOptions{
		MaxConns: int32(cfg.DBMaxConns),
	})
	if err != nil {
		log.Fatal().Err(err).Msg("postgres")
	}
	defer pool.Close()

	migrationsDir := resolveMigrationsDir(cfg.MigrationsDir)
	if err := database.RunMigrations(ctx, pool, migrationsDir); err != nil {
		log.Fatal().Err(err).Msg("migrations")
	}

	rdb, err := database.NewRedis(ctx, database.RedisOptions{
		Addr:     cfg.RedisAddr,
		Password: cfg.RedisPassword,
		DB:       cfg.RedisDB,
		UseTLS:   cfg.RedisTLS,
	})
	if err != nil {
		log.Fatal().Err(err).Msg("redis")
	}
	defer rdb.Close()

	userRepo := repository.NewUserRepository(pool)
	otpRepo := repository.NewOTPRepository(pool)
	chatRepo := repository.NewChatRepository(pool)
	messageRepo := repository.NewMessageRepository(pool)
	authRedis := repository.NewAuthRedisRepository(rdb)
	fileAccessRepo := repository.NewFileAccessRepository(pool)

	jwtManager := utils.NewJWTManager(cfg.JWTSecret, cfg.JWTAccessTTL, cfg.JWTRefreshTTL)
	emailSender := utils.NewEmailSender(cfg.SMTPHost, cfg.SMTPPort, cfg.SMTPUser, cfg.SMTPPassword, cfg.SMTPFrom)
	fileStore := utils.NewFileStore(cfg.UploadDir, cfg.BaseURL)
	if err := fileStore.EnsureDirs(); err != nil {
		log.Fatal().Err(err).Msg("upload dirs")
	}

	hub := services.NewHub(rdb)
	if err := hub.Start(ctx); err != nil {
		log.Fatal().Err(err).Msg("hub start")
	}

	devMode := cfg.Env == "development"
	authSvc := services.NewAuthService(
		userRepo, otpRepo, authRedis, jwtManager, emailSender,
		cfg.JWTRefreshTTL, cfg.OTPExpiry, cfg.RegistrationTTL,
		cfg.OTPPepper, cfg.OTPMaxAttempts, cfg.OTPLockout, devMode,
	)
	userSvc := services.NewUserService(userRepo, fileStore)
	chatSvc := services.NewChatService(chatRepo, userRepo, fileStore, hub)
	fcmSender := services.NewFCMSender(cfg.FCMServerKey)
	msgSvc := services.NewMessageService(messageRepo, chatRepo, userRepo, fileStore, hub, fcmSender)

	authH := handlers.NewAuthHandler(authSvc)
	userH := handlers.NewUserHandler(userSvc)
	deviceH := handlers.NewDeviceHandler(userSvc)
	chatH := handlers.NewChatHandler(chatSvc)
	msgH := handlers.NewMessageHandler(msgSvc)
	wsH := handlers.NewWSHandler(jwtManager, authRedis, msgSvc, hub, cfg.CORSOrigins, cfg.WSPingInterval, cfg.WSReadTimeout)

	rateLimiter := middleware.NewRateLimiter(cfg.AuthRateLimit, cfg.AuthRateWindow)

	app := fiber.New(fiber.Config{
		BodyLimit: 110 * 1024 * 1024,
	})
	app.Use(recover.New())
	app.Use(middleware.Logger())

	allowedOrigins := make(map[string]bool, len(cfg.CORSOrigins))
	for _, o := range cfg.CORSOrigins {
		o = strings.TrimSpace(o)
		if o != "" {
			allowedOrigins[o] = true
		}
	}
	app.Use(cors.New(cors.Config{
		AllowOriginsFunc: func(origin string) bool { return allowedOrigins[origin] },
		AllowHeaders:     "Origin, Content-Type, Accept, Authorization",
		AllowMethods:     "GET,POST,PATCH,DELETE,OPTIONS",
		AllowCredentials: true,
	}))

	api := app.Group("/api")
	auth := api.Group("/auth")
	auth.Use(rateLimiter.Middleware())
	auth.Post("/send-code", authH.SendCode)
	auth.Post("/verify-code", authH.VerifyCode)
	auth.Post("/complete-profile", authH.CompleteProfile)
	auth.Post("/refresh", authH.Refresh)
	auth.Post("/logout", authH.Logout)

	protected := api.Group("", middleware.JWTAuth(jwtManager, authRedis))

	users := protected.Group("/users")
	users.Get("/me", userH.GetMe)
	users.Patch("/me", userH.UpdateMe)
	users.Post("/me/avatar", userH.UploadAvatar)
	users.Get("/search", userH.Search)
	users.Get("/:id", userH.GetByID)

	devices := protected.Group("/devices")
	devices.Post("/push-token", deviceH.SavePushToken)

	chats := protected.Group("/chats")
	chats.Get("/", chatH.List)
	chats.Get("/saved", chatH.GetSaved)
	chats.Post("/direct", chatH.CreateDirect)
	chats.Post("/group", chatH.CreateGroup)
	chats.Get("/:id", chatH.Get)
	chats.Patch("/:id", chatH.Update)
	chats.Delete("/:id", chatH.Delete)
	chats.Post("/:id/mute", chatH.Mute)
	chats.Delete("/:id/mute", chatH.Unmute)
	chats.Post("/:id/members", chatH.AddMembers)
	chats.Delete("/:id/members/:userId", chatH.RemoveMember)
	chats.Delete("/:id/leave", chatH.Leave)

	chats.Get("/:id/messages", msgH.List)
	chats.Post("/:id/messages", msgH.SendText)
	chats.Post("/:id/messages/media", msgH.SendMedia)
	chats.Post("/:id/messages/read", msgH.MarkRead)
	chats.Post("/:id/messages/forward", msgH.Forward)
	chats.Post("/:id/messages/:messageId/save", msgH.SaveToFavorites)
	chats.Get("/:id/messages/search", msgH.Search)
	chats.Delete("/:id/messages", msgH.Clear)
	chats.Get("/:id/pinned", msgH.ListPinned)
	chats.Post("/:id/messages/:messageId/pin", msgH.Pin)
	chats.Delete("/:id/messages/:messageId/pin", msgH.Unpin)
	chats.Patch("/:id/messages/:messageId", msgH.Edit)
	chats.Delete("/:id/messages/:messageId", msgH.Delete)

	app.Get("/uploads/*", middleware.JWTAuth(jwtManager, authRedis), handlers.Uploads(cfg.UploadDir, fileAccessRepo))

	app.Get("/ws", wsH.Upgrade, websocket.New(wsH.Handle()))

	go func() {
		addr := ":" + cfg.Port
		log.Info().Str("addr", addr).Msg("server starting")
		if err := app.Listen(addr); err != nil {
			log.Fatal().Err(err).Msg("listen")
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Info().Msg("shutting down")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := app.ShutdownWithContext(shutdownCtx); err != nil {
		log.Error().Err(err).Msg("shutdown")
	} else {
		log.Info().Msg("server shut down cleanly")
	}
	hub.Stop()
}

func resolveMigrationsDir(fromConfig string) string {
	if fromConfig != "" {
		return fromConfig
	}
	candidates := []string{
		filepath.Join(".", "migrations"),
		filepath.Join("..", "migrations"),
	}
	for _, c := range candidates {
		if _, err := os.Stat(c); !errors.Is(err, os.ErrNotExist) {
			return c
		}
	}
	return candidates[0]
}
