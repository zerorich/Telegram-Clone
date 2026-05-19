import 'package:flutter/material.dart';
import 'package:telegramclone/core/theme.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onAttach,
    required this.onSend,
    required this.onRecordStart,
    required this.onRecordEnd,
    required this.onRecordCancel,
    required this.hasText,
    required this.isRecording,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordEnd;
  final VoidCallback onRecordCancel;
  final bool hasText;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkChatBg,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.darkInput,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.emoji_emotions_outlined,
                        color: AppColors.darkSubtitle,
                        size: 24,
                      ),
                      onPressed: () {},
                      padding: const EdgeInsets.only(left: 4),
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLines: 5,
                        minLines: 1,
                        onChanged: onChanged,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: 'Сообщение',
                          hintStyle: TextStyle(color: AppColors.darkSubtitle),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.attach_file,
                        color: AppColors.darkSubtitle,
                        size: 22,
                      ),
                      onPressed: onAttach,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (hasText)
              IconButton(
                icon: const Icon(Icons.send_rounded, color: AppColors.teal, size: 28),
                onPressed: onSend,
              )
            else
              GestureDetector(
                onLongPressStart: (_) => onRecordStart(),
                onLongPressEnd: (_) => onRecordEnd(),
                onLongPressMoveUpdate: (d) {
                  if (d.localOffsetFromOrigin.dx < -80) onRecordCancel();
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    isRecording ? Icons.mic : Icons.mic_none,
                    color: isRecording ? Colors.red : AppColors.darkSubtitle,
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
