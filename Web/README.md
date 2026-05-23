# Telegram Clone — Web

React + Vite веб-клиент для Telegram Clone, работающий с Go-сервером из
`server/` и повторяющий функциональность мобильного приложения из `App/`.

## Стек

- **Vite + React 19 + JavaScript** — UI и сборка
- **react-router-dom** — роутинг
- **zustand** — состояние
- **axios** — HTTP-клиент с авторефрешем токенов
- **WebSocket API** браузера — реальное время
- **MediaRecorder API** — запись голосовых
- **lucide-react** — иконки
- **date-fns** (с локалью `ru`) — даты
- CSS Modules + CSS-переменные для тем (тёмная / светлая / системная)

## Быстрый старт

```bash
cd Web
npm install
cp .env.example .env   # отредактируйте переменные при необходимости
npm run dev            # http://localhost:5173
```

Соберите для продакшена:

```bash
npm run build
npm run preview        # локальный предпросмотр сборки
```

ESLint:

```bash
npm run lint
```

## Переменные окружения

| Переменная | Назначение | По умолчанию |
| --- | --- | --- |
| `VITE_API_BASE_URL` | базовый URL Go API (используется и для медиа) | `http://localhost:8080` |
| `VITE_WS_URL` | полный URL вебсокета | автогенерация из API URL (`http→ws`, `+ /ws`) |
| `VITE_DEV_PROXY_TARGET` | куда Vite в dev-режиме проксирует `/api`, `/uploads` и `/ws` | `http://localhost:8080` |

Если вы хостите фронтенд и API на одном домене (или используете обратный
прокси-сервер), оставьте `VITE_API_BASE_URL` пустым — запросы пойдут по
относительным путям, и Nginx/Caddy/Traefik сам направит их в бэкенд.

## Что реализовано

- **Аутентификация по email + OTP** (отправка кода, ввод OTP, заполнение
  профиля) с авторефрешем `access_token` через 401-интерсептор.
- **Сайдбар** с поиском по чатам, badges непрочитанного, временем последнего
  сообщения, индикатором онлайн и индикатором печатания.
- **Двухпанельный layout** на десктопе (≥768 px) и одна панель с маршрут-навигацией
  на мобильных. Безопасные зоны iOS (`env(safe-area-inset-*)`) и фикс высоты
  клавиатуры через `visualViewport` (`--keyboard-inset`).
- **Чат**: загрузка по курсору, дата-сепараторы, ответы, редактирование, удаление,
  копирование, прокрутка вниз и кнопка "к новым сообщениям", двойные/одиночные
  галочки прочтения.
- **Медиа**: фото (полноэкранный лайтбокс), видео (HTML5 плеер), файл (скачать),
  голосовое (HTML5 audio с волновой шкалой и счётчиком).
- **Запись голосового** через MediaRecorder — пробует `audio/webm;codecs=opus`,
  падает на `audio/webm`, `audio/ogg`, `audio/mp4` (все эти MIME уже в
  whitelist бэкенда в `server/internal/utils/files.go`).
- **Новый чат** и **новая группа** (поиск, мульти-выбор, аватар группы).
- **Профиль**: просмотр и редактирование своих данных, загрузка аватара,
  выход из аккаунта.
- **Информация о группе**: список участников с ролями, добавление/удаление,
  смена названия/аватара (для админов/владельца), выход из группы.
- **Темы**: тёмная, светлая, системная — сохраняются в `localStorage`.
- **WebSocket** с экспоненциальным бэк-оффом (до 60с), реактивно обновляет
  чат-лист (новые сообщения, печатание, онлайн, чтение, редактирование, удаление).

## Архитектура

```
src/
  api/        axios-клиент + модули (auth, users, chats, messages)
  ws/         WebSocket-клиент и мост к store
  store/      zustand-стораджи: auth, chats, messages, ui
  features/
    auth/     LoginPage, OtpPage, CompleteProfilePage
    chats/    Sidebar, ChatListItem, NewChat/NewGroup modal
    chat/     ChatStage, MessageBubble, MediaContent, VoicePlayer, Composer,
              DateSeparator, TypingIndicator, MediaLightbox
    profile/  ProfileModal, UserProfileModal, GroupInfoModal, SettingsModal
  components/ Avatar, Button, Input, Modal, Spinner, Toast
  hooks/      useMediaQuery, useOpenModal, useVisualViewport
  lib/        env, storage, format, chat-helpers
  routes/     AppLayout
  styles/     tokens.css (цвета/радиусы), global.css
```

Все модальные маршруты используют шаблон "background location":
открытие `/profile`, `/settings`, `/new-chat`, `/new-group`, `/user/:id`,
`/group/:id` рендерит сайдбар + чат как фон, а сам модал — как оверлей.

## Деплой

### Nginx (статика + reverse-proxy для API/uploads/WS)

```nginx
server {
  listen 80;
  server_name your.domain;

  root /var/www/telegramclone/dist;
  index index.html;

  # SPA fallback — все маршруты ведут на index.html
  location / {
    try_files $uri /index.html;
  }

  # API
  location /api/ {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Real-IP $remote_addr;
  }

  # Загруженные файлы
  location /uploads/ {
    proxy_pass http://127.0.0.1:8080;
  }

  # WebSocket
  location /ws {
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 86400s;
  }
}
```

С такой схемой в `.env` достаточно оставить `VITE_API_BASE_URL=` пустым:
браузер будет ходить по относительным `/api`, `/uploads`, `/ws`.

### Cloudflare/Vercel + отдельный бэкенд

Если фронтенд и бэкенд на разных доменах, укажите полный
`VITE_API_BASE_URL=https://api.example.com` и убедитесь, что в Go-сервере
для CORS разрешён origin фронтенда (см. `server/internal/config/config.go`
и middleware с CORS).

## Команды

| Команда | Назначение |
| --- | --- |
| `npm run dev` | dev-сервер (HMR) на 5173 с прокси `/api`, `/uploads`, `/ws` |
| `npm run build` | сборка в `dist/` |
| `npm run preview` | локальный предпросмотр сборки |
| `npm run lint` | ESLint |

## Ограничения

- Эмодзи-пикер не реализован — нативной клавиатуры обычно достаточно для веба.
- Сжатие изображений на клиенте не делается; бэкенд режет аватарки сам, остальные
  файлы отправляются как есть (в пределах лимитов сервера).
- Виртуализации списка сообщений нет — для очень длинных чатов это может быть
  медленно, но cursor-пагинация подгружает по 50 сообщений.
- Реакции, опросы, видеосообщения и видеозвонки — вне рамок клона.
