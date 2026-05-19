import 'package:intl/intl.dart';
import 'package:telegramclone/data/models/message.dart';

/// Telegram-style relative time for chat list.
String formatChatListTime(DateTime time) {
  final now = DateTime.now();
  final local = time.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(local.year, local.month, local.day);

  if (msgDay == today) {
    return DateFormat.Hm().format(local);
  }

  final diff = today.difference(msgDay).inDays;
  if (diff < 7) {
    return DateFormat.E('ru').format(local).toUpperCase();
  }

  if (local.year == now.year) {
    return DateFormat('d MMM', 'ru').format(local);
  }
  return DateFormat('dd.MM.yy').format(local);
}

/// Date pill above message groups in chat (Сегодня / Вчера / 6 мая).
String formatChatDateSeparator(DateTime time) {
  final now = DateTime.now();
  final local = time.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);

  if (day == today) return 'Сегодня';
  if (day == today.subtract(const Duration(days: 1))) return 'Вчера';
  return DateFormat('d MMMM', 'ru').format(local);
}

String formatMessagePreview({
  required String? content,
  required MessageType type,
  required bool isMine,
  String? senderName,
  bool isGroup = false,
}) {
  String body;
  switch (type) {
    case MessageType.image:
      body = 'Фото';
      break;
    case MessageType.video:
      body = 'Видео';
      break;
    case MessageType.voice:
      body = 'Голосовое сообщение';
      break;
    case MessageType.file:
      body = 'Файл';
      break;
    default:
      body = content ?? '';
  }

  if (isMine) {
    return 'Вы: $body';
  }
  if (isGroup && senderName != null && senderName.isNotEmpty) {
    return '$senderName: $body';
  }
  return body;
}
