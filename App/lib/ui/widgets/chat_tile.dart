import 'package:flutter/material.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/format_utils.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/data/models/chat.dart';
import 'package:telegramclone/ui/widgets/avatar_widget.dart';

class ChatTile extends StatelessWidget {
  final ChatModel chat;
  final String currentUserId;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = chat.displayTitle(currentUserId);
    final last = chat.lastMessage;
    final isGroup = chat.type == ChatType.group;
    final isMine = last?.senderId == currentUserId;
    final time = last?.createdAt ?? chat.createdAt;
    final timeStr = formatChatListTime(time);
    final avatarPath = chat.peerAvatarUrl(currentUserId);
    final hasUnread = chat.unreadCount > 0;

    String? senderName;
    if (isGroup && last != null && !isMine) {
      final peer = chat.members
          .where((m) => m.userId == last.senderId)
          .firstOrNull;
      senderName = peer?.user?.displayName;
    }

    final preview = last == null
        ? 'Нет сообщений'
        : formatMessagePreview(
            content: last.content,
            type: last.type,
            isMine: isMine,
            senderName: senderName,
            isGroup: isGroup,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarWidget(
                imageUrl: avatarPath != null && avatarPath.isNotEmpty
                    ? AppConstants.mediaUrl(avatarPath)
                    : null,
                name: title,
                size: 54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread ? AppColors.teal : AppColors.darkSubtitle,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isMine && last != null) ...[
                          Icon(
                            last.isRead ? Icons.done_all : Icons.done,
                            size: 16,
                            color: AppColors.darkSubtitle,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              color: hasUnread ? Colors.white70 : AppColors.darkSubtitle,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (hasUnread) _UnreadBadge(count: chat.unreadCount),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 999 ? '${(count / 1000).floor()}K' : '$count';
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: AppColors.unreadBadge,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
