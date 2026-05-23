import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/data/models/message.dart';
import 'package:telegramclone/ui/widgets/media_message.dart';
import 'package:telegramclone/ui/widgets/voice_message_player.dart';
import 'package:url_launcher/url_launcher.dart';

final _urlRegex = RegExp(r'https?://[^\s]+');

class MessageBubble extends StatefulWidget {
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

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  final List<TapGestureRecognizer> _recognizers = [];
  late final AnimationController _appearCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _appearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _appearCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: Offset(widget.isMine ? 0.04 : -0.04, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _appearCtrl, curve: Curves.easeOut));
    _appearCtrl.forward();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _appearCtrl.dispose();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _linkifiedText(String text, Color color) {
    _disposeRecognizers();
    final spans = <TextSpan>[];
    int start = 0;
    for (final m in _urlRegex.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, m.start),
          style: TextStyle(color: color, fontSize: 15.5, height: 1.3),
        ));
      }
      final url = m.group(0)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _openUrl(url);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: url,
        style: const TextStyle(
          color: AppColors.tealLight,
          fontSize: 15.5,
          height: 1.3,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.tealLight,
        ),
        recognizer: recognizer,
      ));
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(color: color, fontSize: 15.5, height: 1.3),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _timeRow(Color timeColor) {
    final time = DateFormat('HH:mm').format(widget.message.createdAt.toLocal());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.message.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              'изм.',
              style: TextStyle(fontSize: 11, color: timeColor),
            ),
          ),
        Text(time, style: TextStyle(fontSize: 11.5, color: timeColor)),
        if (widget.isMine) ...[
          const SizedBox(width: 3),
          Icon(
            widget.message.isRead
                ? Icons.done_all_rounded
                : Icons.done_rounded,
            size: 14,
            color: widget.message.isRead
                ? AppColors.tealLight.withValues(alpha: 0.9)
                : timeColor,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMine = widget.isMine;
    final message = widget.message;
    final senderName = widget.senderName;
    final replyTo = widget.replyTo;

    // Updated colors: mine = dark Telegram blue, received = dark navy
    final bg = isMine ? AppColors.darkBubbleMine : AppColors.darkBubbleReceived;
    // Both use white text now (bubble is always dark)
    const fg = Colors.white;
    final timeColor = Colors.white.withValues(alpha: isMine ? 0.65 : 0.5);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: widget.onLongPress ?? widget.onReply,
            child: Container(
              margin: EdgeInsets.only(
                left: isMine ? 52 : 8,
                right: isMine ? 8 : 52,
                top: 2,
                bottom: 2,
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 5),
                  bottomRight: Radius.circular(isMine ? 5 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (senderName != null && !isMine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        senderName,
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  if (message.isForwarded) _forwardedHeader(),
                  if (replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: const Border(
                          left: BorderSide(color: AppColors.teal, width: 3),
                        ),
                      ),
                      child: Text(
                        replyTo.content ?? _typeLabel(replyTo.type),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (message.isDeleted) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.block_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Сообщение удалено',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _timeRow(timeColor),
                    ),
                  ] else if (message.type == MessageType.text &&
                      message.content != null) ...[
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        _linkifiedText(message.content!, fg),
                        _timeRow(timeColor),
                      ],
                    ),
                  ] else ...[
                    if (message.type == MessageType.voice)
                      VoiceMessagePlayer(
                        url: message.fullMediaUrl,
                        durationSec: message.durationSec,
                        isMine: isMine,
                      ),
                    if ([
                      MessageType.image,
                      MessageType.video,
                      MessageType.file
                    ].contains(message.type))
                      MediaMessage(message: message, isMine: isMine),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _timeRow(timeColor),
                    ),
                  ],
                ],
              ),
            ),
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

  Widget _forwardedHeader() {
    final name = widget.message.forwardedFromUser?.displayName ??
        'неизвестного пользователя';
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.reply_rounded,
            size: 13,
            color: AppColors.teal,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Переслано от $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.teal,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
