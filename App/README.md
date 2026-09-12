# Telegram Clone — Flutter App

Мобильный клиент (Android) для мессенджера Telegram Clone.

## Требования

- [Flutter](https://docs.flutter.dev/get-started/install) (stable)
- Запущенный Go-бэкенд из [`../server/`](../server/)

## Установка и запуск

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=WS_URL=ws://10.0.2.2:8080/ws
```

### Переменные сборки (`--dart-define`)

| Переменная | Назначение | Эмулятор Android |
| --- | --- | --- |
| `API_BASE_URL` | Базовый URL REST API | `http://10.0.2.2:8080` |
| `WS_URL` | Полный URL WebSocket | `ws://10.0.2.2:8080/ws` |

`10.0.2.2` — loopback хост-машины из Android-эмулятора.

На **физическом устройстве** укажите LAN IP компьютера с сервером, например:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.100:8080 \
  --dart-define=WS_URL=ws://192.168.1.100:8080/ws
```

Значения читаются в `lib/core/constants.dart` через `String.fromEnvironment`.

## Аутентификация

Вход только по **email + OTP** (без пароля):

1. **Email** — пользователь вводит адрес, приложение вызывает `POST /api/auth/send-code`.
2. **OTP** — ввод 6-значного кода, `POST /api/auth/verify-code`.
3. **Профиль** (новые пользователи) — имя, фамилия, телефон; `POST /api/auth/complete-profile` с registration token.

Существующие пользователи после шага 2 сразу получают access/refresh tokens.

В dev-режиме сервера OTP печатается в консоль API, если SMTP не настроен.

## Возможности

- Список чатов с поиском и pull-to-refresh
- Realtime через WebSocket
- Текст, изображения, видео, файлы, голосовые сообщения
- Личные и групповые чаты, 1:1 звонки (WebRTC)
- Push: FCM + локальные уведомления (замените `android/app/google-services.json` на свой Firebase-проект)
- Профиль и настройки (светлая / тёмная тема, уведомления)

## Тема и токены

Цвета и отступы генерируются из [`../design/tokens.json`](../design/tokens.json):

```bash
node ../design/generate.mjs
```

См. [`../design/README.md`](../design/README.md).

## Первый запуск

Если каталог `android/` был создан вручную:

```bash
flutter create . --project-name telegramclone
```

Сохраните `lib/` и `pubspec.yaml` как источник правды.
