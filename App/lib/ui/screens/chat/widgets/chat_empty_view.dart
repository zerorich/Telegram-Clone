import 'package:flutter/material.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/core/theme_extensions.dart';

class ChatEmptyView extends StatelessWidget {
  const ChatEmptyView({super.key, required this.isSaved});

  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.teal.withValues(alpha: 0.1),
              ),
              child: Icon(
                isSaved ? Icons.bookmark_rounded : Icons.chat_bubble_outline_rounded,
                size: 40,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSaved ? 'Сохранённые сообщения' : 'Нет сообщений',
              style: TextStyle(
                color: context.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSaved
                  ? 'Пересылайте сюда важные сообщения, чтобы не потерять'
                  : 'Будьте первым, кто напишет!\nНачните общение прямо сейчас.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.subtitleColor,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
