import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/data/models/message.dart';
import 'package:telegramclone/ui/widgets/media_message.dart';
import 'package:telegramclone/ui/widgets/voice_message_player.dart';

final _urlRegex = RegExp(r'https?://[^\s]+');

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final String? senderName;
  final MessageModel? replyTo;
  final VoidCallback? onReply;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.senderName,
    this.replyTo,
    this.onReply,
    this.onLongPress,
  });

  Widget _linkifiedText(String text, Color color) {
    final spans = <TextSpan>[];
    int start = 0;
    for (final m in _urlRegex.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, m.start),
          style: TextStyle(color: color, fontSize: 16, height: 1.25),
        ));
      }
      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(
          color: color,
          fontSize: 16,
          height: 1.25,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()..onTap = () {},
      ));
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(color: color, fontSize: 16, height: 1.25),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _timeRow(Color timeColor, Color checkColor) {
    final time = DateFormat('h:mm:ss a').format(message.createdAt.toLocal());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              'изм.',
              style: TextStyle(fontSize: 11, color: timeColor),
            ),
          ),
        Text(time, style: TextStyle(fontSize: 11, color: timeColor)),
        if (isMine) ...[
          const SizedBox(width: 3),
          Icon(
            message.isRead ? Icons.done_all : Icons.done,
            size: 15,
            color: timeColor,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = isMine ? AppColors.darkBubbleMine : AppColors.darkBubbleReceived;
    final fg = isMine ? Colors.black87 : Colors.white;
    final timeColor =
        isMine ? Colors.black.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.5);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress ?? onReply,
        child: Container(
          margin: EdgeInsets.only(
            left: isMine ? 56 : 8,
            right: isMine ? 8 : 56,
            top: 2,
            bottom: 2,
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (senderName != null && !isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    senderName!,
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              if (replyTo != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: const Border(
                      left: BorderSide(color: AppColors.teal, width: 3),
                    ),
                  ),
                  child: Text(
                    replyTo!.content ?? _typeLabel(replyTo!.type),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 13),
                  ),
                ),
              if (message.isDeleted) ...[
                Text(
                  'Сообщение удалено',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.55),
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: _timeRow(timeColor, timeColor),
                ),
              ] else if (message.type == MessageType.text && message.content != null) ...[
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    _linkifiedText(message.content!, fg),
                    _timeRow(timeColor, timeColor),
                  ],
                ),
              ] else ...[
                if (message.type == MessageType.voice)
                  VoiceMessagePlayer(
                    url: message.fullMediaUrl,
                    durationSec: message.durationSec,
                    isMine: isMine,
                  ),
                if ([MessageType.image, MessageType.video, MessageType.file]
                    .contains(message.type))
                  MediaMessage(message: message, isMine: isMine),
                Align(
                  alignment: Alignment.centerRight,
                  child: _timeRow(timeColor, timeColor),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(MessageType t) {
    switch (t) {
      case MessageType.image:
        return 'Фото';
      case MessageType.video:
        return 'Видео';
      case MessageType.voice:
        return 'Голосовое';
      case MessageType.file:
        return 'Файл';
      default:
        return '';
    }
  }
}
