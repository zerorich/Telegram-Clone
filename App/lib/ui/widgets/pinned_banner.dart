import 'package:flutter/material.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/data/models/message.dart';

/// 44dp banner above the chat list showing a preview of the latest pinned
/// message. Tap to jump to it.
class PinnedBanner extends StatelessWidget {
  const PinnedBanner({
    super.key,
    required this.message,
    required this.onTap,
    this.totalPinned = 1,
  });

  final MessageModel message;
  final int totalPinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = _preview(message);
    return Material(
      color: const Color(0xFF14181C),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Container(
                width: 3,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      totalPinned > 1
                          ? 'Закреплённое ($totalPinned)'
                          : 'Закреплённое сообщение',
                      style: const TextStyle(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.push_pin, size: 18, color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _preview(MessageModel m) {
    if (m.isDeleted) return 'Сообщение удалено';
    switch (m.type) {
      case MessageType.image:
        return 'Фото';
      case MessageType.video:
        return 'Видео';
      case MessageType.voice:
        return 'Голосовое сообщение';
      case MessageType.file:
        return 'Файл';
      default:
        return m.content ?? '';
    }
  }
}
