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
      color: AppColors.darkAppBar,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Input field container
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                decoration: BoxDecoration(
                  color: AppColors.darkInput,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.darkSubtitle.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _IconBtn(
                      icon: Icons.emoji_emotions_outlined,
                      onPressed: () {},
                      color: AppColors.darkSubtitle,
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLines: 5,
                        minLines: 1,
                        onChanged: onChanged,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Сообщение',
                          hintStyle: TextStyle(
                            color: AppColors.darkSubtitle,
                            fontSize: 15.5,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    _IconBtn(
                      icon: Icons.attach_file_rounded,
                      onPressed: onAttach,
                      color: AppColors.darkSubtitle,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Animated Send / Mic button
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: hasText
                  ? _SendButton(key: const ValueKey('send'), onSend: onSend)
                  : _MicButton(
                      key: const ValueKey('mic'),
                      isRecording: isRecording,
                      onRecordStart: onRecordStart,
                      onRecordEnd: onRecordEnd,
                      onRecordCancel: onRecordCancel,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  const _IconBtn({
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final VoidCallback onSend;

  const _SendButton({super.key, required this.onSend});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() async {
    await _ctrl.reverse();
    await _ctrl.forward();
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.teal, AppColors.tealDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.send_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordEnd;
  final VoidCallback onRecordCancel;

  const _MicButton({
    super.key,
    required this.isRecording,
    required this.onRecordStart,
    required this.onRecordEnd,
    required this.onRecordCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => onRecordStart(),
      onLongPressEnd: (_) => onRecordEnd(),
      onLongPressMoveUpdate: (d) {
        if (d.localOffsetFromOrigin.dx < -80) onRecordCancel();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording
              ? Colors.redAccent.withValues(alpha: 0.15)
              : Colors.transparent,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Icon(
              isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
              key: ValueKey(isRecording),
              color: isRecording ? Colors.redAccent : AppColors.darkSubtitle,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
