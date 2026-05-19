package main

import (
	"context"
	"os"
	"os/signal"
	"path/filepath"
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

	ctx := context.Background()

	pool, err := database.NewPostgres(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatal().Err(err).Msg("postgres")
	}
	defer pool.Close()

	migrationsDir := filepath.Join(".", "migrations")
	if _, err := os.Stat(migrationsDir); os.IsNotExist(err) {
		migrationsDir = filepath.Join("..", "migrations")
	}
	if err := database.RunMigrations(ctx, pool, migrationsDir); err != nil {
		log.Fatal().Err(err).Msg("migrations")
	}

	rdb, err := database.NewRedis(ctx, cfg.RedisAddr, cfg.RedisPassword, cfg.RedisDB)
	if err != nil {
		log.Fatal().Err(err).Msg("redis")
	}
	defer rdb.Close()

	// Repositories
	userRepo := repository.NewUserRepository(pool)
	otpRepo := repository.NewOTPRepository(pool)
	chatRepo := repository.NewChatRepository(pool)
	messageRepo := repository.NewMessageRepository(pool)
	authRedis := repository.NewAuthRedisRepository(rdb)

	// Utils
	jwtManager := utils.NewJWTManager(cfg.JWTSecret, cfg.JWTAccessTTL, cfg.JWTRefreshTTL)
	emailSender := utils.NewEmailSender(cfg.SMTPHost, cfg.SMTPPort, cfg.SMTPUser, cfg.SMTPPassword, cfg.SMTPFrom)
	fileStore := utils.NewFileStore(cfg.UploadDir, cfg.BaseURL)
	if err := fileStore.EnsureDirs(); err != nil {
		log.Fatal().Err(err).Msg("upload dirs")
	}

	// Services
	hub := services.NewHub(rdb)
	if err := hub.Start(ctx); err != nil {
		log.Fatal().Err(err).Msg("hub start")
	}
	defer hub.Stop()

	devMode := cfg.Env == "development"
	authSvc := services.NewAuthService(userRepo, otpRepo, authRedis, jwtManager, emailSender, cfg.JWTRefreshTTL, devMode)
	userSvc := services.NewUserService(userRepo, fileStore)
	chatSvc := services.NewChatService(chatRepo, userRepo, fileStore)
	msgSvc := services.NewMessageService(messageRepo, chatRepo, userRepo, fileStore, hub)

	// Handlers
	authH := handlers.NewAuthHandler(authSvc)
	userH := handlers.NewUserHandler(userSvc)
	chatH := handlers.NewChatHandler(chatSvc)
	msgH := handlers.NewMessageHandler(msgSvc)
	wsH := handlers.NewWSHandler(jwtManager, msgSvc, hub)

	rateLimiter := middleware.NewRateLimiter(cfg.AuthRateLimit, cfg.AuthRateWindow)

	app := fiber.New(fiber.Config{
		BodyLimit: 110 * 1024 * 1024,
	})
	app.Use(recover.New())
	app.Use(middleware.Logger())
	app.Use(cors.New(cors.Config{
		AllowOrigins:     joinOrigins(cfg.CORSOrigins),
		AllowHeaders:     "Origin, Content-Type, Accept, Authorization",
		AllowMethods:     "GET,POST,PATCH,DELETE,OPTIONS",
		AllowCredentials: true,
	}))

	app.Get("/uploads/*", handlers.Uploads(cfg.UploadDir))

	api := app.Group("/api")
	auth := api.Group("/auth")
	auth.Use(rateLimiter.Middleware())
	auth.Post("/send-code", authH.SendCode)
	auth.Post("/verify-code", authH.VerifyCode)
	auth.Post("/complete-profile", authH.CompleteProfile)
	auth.Post("/refresh", authH.Refresh)
	auth.Post("/logout", authH.Logout)

	protected := api.Group("", middleware.JWTAuth(jwtManager))

	users := protected.Group("/users")
	users.Get("/me", userH.GetMe)
	users.Patch("/me", userH.UpdateMe)
	users.Post("/me/avatar", userH.UploadAvatar)
	users.Get("/search", userH.Search)
	users.Get("/:id", userH.GetByID)

	chats := protected.Group("/chats")
	chats.Get("/", chatH.List)
	chats.Post("/direct", chatH.CreateDirect)
	chats.Post("/group", chatH.CreateGroup)
	chats.Get("/:id", chatH.Get)
	chats.Patch("/:id", chatH.Update)
	chats.Post("/:id/members", chatH.AddMembers)
	chats.Delete("/:id/members/:userId", chatH.RemoveMember)
	chats.Delete("/:id/leave", chatH.Leave)

	chats.Get("/:id/messages", msgH.List)
	chats.Post("/:id/messages", msgH.SendText)
	chats.Post("/:id/messages/media", msgH.SendMedia)
	chats.Post("/:id/messages/read", msgH.MarkRead)
	chats.Patch("/:id/messages/:messageId", msgH.Edit)
	chats.Delete("/:id/messages/:messageId", msgH.Delete)

	app.Get("/ws", websocket.New(wsH.Handle()))

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
	_ = shutdownCtx
	if err := app.Shutdown(); err != nil {
		log.Error().Err(err).Msg("shutdown")
	}
}

func joinOrigins(origins []string) string {
	result := ""
	for i, o := range origins {
		if i > 0 {
			result += ","
		}
		result += o
	}
	return result
}
