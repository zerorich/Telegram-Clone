import 'package:flutter/material.dart';
import 'package:telegramclone/core/format_utils.dart';
import 'package:telegramclone/data/models/chat_member.dart';
import 'package:telegramclone/data/models/message.dart';
import 'package:telegramclone/providers/messages_provider.dart';
import 'package:telegramclone/ui/widgets/date_separator.dart';
import 'package:telegramclone/ui/widgets/message_bubble.dart';

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.scrollController,
    required this.messagesState,
    required this.userId,
    required this.isGroup,
    required this.isSaved,
    required this.chatDetailMembers,
    required this.listChatMembers,
    required this.onReply,
    required this.onLongPress,
  });

  final ScrollController scrollController;
  final MessagesState messagesState;
  final String userId;
  final bool isGroup;
  final bool isSaved;
  final List<ChatMemberModel>? chatDetailMembers;
  final List<ChatMemberModel>? listChatMembers;
  final void Function(MessageModel msg) onReply;
  final void Function(MessageModel msg, {required bool isMine, required bool isGroup})
      onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messagesState.messages.length +
          (messagesState.isLoadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (messagesState.isLoadingMore &&
            i == messagesState.messages.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final idx = messagesState.messages.length - 1 - i;
        final msg = messagesState.messages[idx];
        final showDate = idx == 0 ||
            !_sameDay(
              messagesState.messages[idx - 1].createdAt,
              msg.createdAt,
            );
        final isMine = isSaved || msg.senderId == userId;
        MessageModel? reply;
        if (msg.replyToId != null) {
          final replies =
              messagesState.messages.where((m) => m.id == msg.replyToId);
          reply = replies.isEmpty ? null : replies.first;
        }
        String? senderName;
        if (isGroup && !isMine) {
          final members =
              (chatDetailMembers ?? listChatMembers ?? const <ChatMemberModel>[])
                  .where((m) => m.userId == msg.senderId);
          final member = members.isEmpty ? null : members.first;
          senderName = member?.user?.displayName;
        }
        return Column(
          children: [
            if (showDate)
              DateSeparator(label: formatChatDateSeparator(msg.createdAt)),
            MessageBubble(
              message: msg,
              isMine: isMine,
              senderName: senderName,
              replyTo: reply,
              onReply: () => onReply(msg),
              onLongPress: () => onLongPress(msg, isMine: isMine, isGroup: isGroup),
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    final al = a.toLocal();
    final bl = b.toLocal();
    return al.year == bl.year && al.month == bl.month && al.day == bl.day;
  }
}
