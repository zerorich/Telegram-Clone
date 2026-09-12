# Design system — Telegram Clone

Единый источник правды для цветов, отступов, типографики, радиусов и теней мобильного (Flutter) и веб-клиента (React).

## Структура

```
design/
├── tokens.json          # исходные токены (редактировать здесь)
├── generate.mjs         # генератор артефактов
├── generated/
│   └── tokens.dart      # копия для справки (зеркало App/lib/core/generated/)
└── README.md
```

## Генерация

Из корня репозитория:

```bash
node design/generate.mjs
```

Скрипт обновляет:

| Выход | Назначение |
| --- | --- |
| `App/lib/core/generated/tokens.dart` | константы `AppTokens` / `AppColors` для Flutter |
| `Web/src/styles/tokens.css` | CSS-переменные для веб-клиента |

После изменения `tokens.json` **всегда** запускайте генератор, чтобы оба клиента оставались синхронными.

## Редактирование токенов

1. Измените `design/tokens.json`.
2. Запустите `node design/generate.mjs`.
3. При необходимости подстройте компонентные темы в `App/lib/core/theme.dart` (AppBar, inputs, dialogs и т.д.) — они используют сгенерированные константы, но не перезаписываются скриптом.

### Соглашения

- **brand** — фирменный голубой Telegram (`#2AABEE`).
- **color.dark** / **color.light** — семантические поверхности и текст для тёмной и светлой темы.
- **spacing**, **radius**, **typography** — общие числовые шкалы.
- **layout** — размеры shell (header, sidebar); в основном для Web.
- **avatar.gradients** — палитра буквенных аватаров (Web).

Значения выведены из существующих `App/lib/core/theme.dart` и `Web/src/styles/tokens.css` и унифицированы (например, `--bg-input` / `darkBgInput` → `#242F3D`).

## Flutter

```dart
import 'package:telegramclone/core/theme.dart';

// AppColors — обратно совместимые алиасы
// AppTokens — полный набор токенов
AppColors.teal;
AppTokens.radiusMd;
```

`AppTheme.dark()` и `AppTheme.light()` в `theme.dart` настраивают Material-компоненты поверх токенов.

## Web

`Web/src/styles/tokens.css` подключается в `global.css`. Тема переключается атрибутом `data-theme="dark"|"light"` на корневом элементе.

Переменные: `--brand`, `--bg`, `--text-muted`, `--radius-md`, `--shadow-1` и т.д.
