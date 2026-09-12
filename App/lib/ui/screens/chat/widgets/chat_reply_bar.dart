import 'package:flutter/material.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/data/models/message.dart';

class ChatReplyBar extends StatelessWidget {
  const ChatReplyBar({
    super.key,
    required this.replyTo,
    required this.onClear,
  });

  final MessageModel replyTo;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: context.tileHighlight,
        border: Border(top: BorderSide(color: context.dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ответить',
                  style: TextStyle(
                    color: AppColors.teal,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyTo.content ?? 'медиа',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.primaryText.withValues(alpha: 0.7),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Отменить ответ',
            button: true,
            child: IconButton(
              icon: Icon(Icons.close_rounded, size: 20, color: context.subtitleColor),
              onPressed: onClear,
            ),
          ),
        ],
      ),
    );
  }
}
