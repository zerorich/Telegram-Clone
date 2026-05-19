# Telegram Clone — Go Backend

Production-ready REST + WebSocket API for the messenger app.

## Prerequisites

- Go 1.22+
- PostgreSQL 16+
- Redis 7+

## Quick start

1. Start dependencies (PostgreSQL 16 + Redis 7):

```bash
docker compose up -d
```

Optional pgAdmin UI (http://localhost:5050 — `admin@local.dev` / `admin`):

```bash
docker compose --profile tools up -d
```

In pgAdmin, add a server: host `postgres`, port `5432`, user `postgres`, password `postgres`, database `telegramclone`.

2. Copy environment file and adjust if needed:

```bash
cp .env.example .env
```

3. Run the server (from `server/` directory):

```bash
go mod tidy
go run cmd/main.go
```

Migrations run automatically on startup.

In **development** mode (`ENV=development`), OTP codes are logged to the console if SMTP is not configured.

## API

- Base URL: `http://localhost:8080`
- Auth: `Authorization: Bearer <access_token>`
- WebSocket: `ws://localhost:8080/ws?token=<access_token>`

All JSON responses: `{ "success": true, "data": {} }` or `{ "success": false, "error": "..." }`.

## Docker (production)

```bash
docker build -t telegramclone-server .
docker run -p 8080:8080 --env-file .env telegramclone-server
```

## Project layout

```
server/
├── cmd/main.go           # entrypoint
├── internal/
│   ├── config/           # env configuration
│   ├── database/         # postgres + redis
│   ├── handlers/         # HTTP + WS handlers
│   ├── middleware/       # auth, logging, rate limit
│   ├── models/           # domain types
│   ├── repository/       # data access
│   ├── services/         # business logic + WS hub
│   └── utils/            # jwt, files, email, etc.
├── migrations/001_init.sql
└── uploads/              # local file storage
```
