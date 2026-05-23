import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:telegramclone/core/theme.dart';

class OtpInput extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;

  const OtpInput({
    super.key,
    this.length = 6,
    required this.onCompleted,
  });

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus so the keyboard appears immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focus.requestFocus(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Adaptive boxes row ───────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              // Available width minus gaps between boxes
              final totalGap = (widget.length - 1) * 8.0;
              final boxW = ((constraints.maxWidth - totalGap) / widget.length)
                  .clamp(38.0, 56.0);
              final boxH = (boxW * 1.2).clamp(46.0, 64.0);

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.length, (i) {
                  final char = i < _controller.text.length
                      ? _controller.text[i]
                      : '';
                  final isFilled = char.isNotEmpty;
                  final isActive = i == _controller.text.length &&
                      _focus.hasFocus;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: boxW,
                    height: boxH,
                    margin: EdgeInsets.only(
                      right: i < widget.length - 1 ? 8 : 0,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isFilled
                          ? AppColors.teal.withValues(alpha: 0.12)
                          : AppColors.darkTileHighlight,
                      border: Border.all(
                        color: isActive
                            ? AppColors.teal
                            : isFilled
                                ? AppColors.teal.withValues(alpha: 0.5)
                                : AppColors.darkSubtitle
                                    .withValues(alpha: 0.25),
                        width: isActive ? 2.0 : 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: char.isNotEmpty
                        ? Text(
                            char,
                            style: TextStyle(
                              fontSize: boxW * 0.45,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          )
                        : isActive
                            ? _Cursor(height: boxH * 0.45)
                            : null,
                  );
                }),
              );
            },
          ),

          // ── Hidden text field ────────────────────────────────
          SizedBox(
            height: 1,
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  setState(() {});
                  if (v.length == widget.length) widget.onCompleted(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blinking cursor indicator shown in the active empty box
class _Cursor extends StatefulWidget {
  final double height;

  const _Cursor({required this.height});

  @override
  State<_Cursor> createState() => _CursorState();
}

class _CursorState extends State<_Cursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.teal,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
