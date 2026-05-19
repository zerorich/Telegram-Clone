# Telegram Clone — Flutter App

Mobile client for the Telegram Clone messenger.

## Setup

1. Install [Flutter](https://docs.flutter.dev/get-started/install) (stable channel).

2. From this directory:

```bash
flutter pub get
flutter run
```

3. Ensure the Go backend is running (`server/` on port 8080).

## API base URL

Edit `lib/core/constants.dart`:

- **Android emulator:** `http://10.0.2.2:8080` (default)
- **Physical device:** use your machine's LAN IP, e.g. `http://192.168.1.100:8080`

Also update `wsUrl` to match (`ws://...`).

## Features

- Registration (phone + email → OTP → profile)
- Login (email or phone + password)
- Chat list with search and pull-to-refresh
- Real-time messaging via WebSocket
- Text, image, file, voice messages
- Direct and group chats
- Profile and settings (dark/light theme)

## First run

If the Android folder was generated manually, run once:

```bash
flutter create . --project-name telegramclone
```

This merges platform files; keep `lib/` and `pubspec.yaml` as the source of truth.
