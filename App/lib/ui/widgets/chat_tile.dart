import 'package:flutter/material.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/format_utils.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/data/models/chat.dart';
import 'package:telegramclone/ui/widgets/avatar_widget.dart';

class ChatTile extends StatefulWidget {
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
  State<ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<ChatTile>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final currentUserId = widget.currentUserId;

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
        ? (chat.isSaved
            ? 'Сохраняйте важные сообщения здесь'
            : 'Нет сообщений')
        : formatMessagePreview(
            content: last.content,
            type: last.type,
            isMine: isMine && !chat.isSaved,
            senderName: senderName,
            isGroup: isGroup,
          );

    return Semantics(
      label: 'Чат $title',
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _pressed ? context.tileActive : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          splashColor: AppColors.teal.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    AvatarWidget(
                      imageUrl: avatarPath != null && avatarPath.isNotEmpty
                          ? AppConstants.mediaUrl(avatarPath)
                          : null,
                      name: title,
                      size: 54,
                      isSaved: chat.isSaved,
                    ),
                    if (chat.isMuted)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.scaffoldBg,
                          ),
                          child: Icon(
                            Icons.notifications_off_rounded,
                            size: 12,
                            color: context.subtitleColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: context.primaryText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: hasUnread
                                  ? AppColors.teal
                                  : context.subtitleColor,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (isMine && last != null && !chat.isSaved) ...[
                            Icon(
                              last.isRead
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                              size: 15,
                              color: last.isRead
                                  ? AppColors.teal
                                  : context.subtitleColor,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                color: hasUnread
                                    ? context.primaryText.withValues(alpha: 0.75)
                                    : context.subtitleColor,
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            _UnreadBadge(
                              count: chat.unreadCount,
                              muted: chat.isMuted,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.muted});

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final label = count > 999 ? '${(count / 1000).floor()}K' : '$count';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: muted ? context.mutedBadgeFill : AppColors.unreadBadge,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
