# Telegram Clone — Go Backend

Production-ready REST + WebSocket API for the messenger app.

Обзор монорепозитория, архитектура и запуск всех клиентов: [`../README.md`](../README.md).

## Prerequisites

- Go 1.22+
- PostgreSQL 16+
- Redis 7+

## Quick start

1. Copy the environment file and set real values — **required** before `docker compose up`,
   since the compose file reads `POSTGRES_PASSWORD` / `PGADMIN_DEFAULT_PASSWORD` from it and
   refuses to start with defaults:

```bash
cp .env.example .env
# then edit .env: set POSTGRES_PASSWORD, PGADMIN_DEFAULT_PASSWORD, JWT_SECRET, OTP_PEPPER
```

2. Start dependencies (PostgreSQL 16 + Redis 7 + the API itself):

```bash
docker compose up -d
```

Optional pgAdmin UI (http://localhost:5050 — email/password from `PGADMIN_DEFAULT_EMAIL` /
`PGADMIN_DEFAULT_PASSWORD` in `.env`):

```bash
docker compose --profile tools up -d
```

In pgAdmin, add a server: host `postgres`, port `5432`, user `POSTGRES_USER`, password
`POSTGRES_PASSWORD`, database `POSTGRES_DB` (all from `.env`).

3. Run the server locally instead of via Docker (from `server/` directory) — reads the same `.env`:

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
