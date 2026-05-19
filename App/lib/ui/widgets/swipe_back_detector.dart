import 'package:flutter/material.dart';

/// iOS-style back gesture: drag from the left edge toward the right.
class SwipeBackDetector extends StatefulWidget {
  const SwipeBackDetector({
    super.key,
    required this.child,
    required this.onBack,
  });

  final Widget child;
  final VoidCallback onBack;

  @override
  State<SwipeBackDetector> createState() => _SwipeBackDetectorState();
}

class _SwipeBackDetectorState extends State<SwipeBackDetector> {
  double _dragDx = 0;
  bool _fromEdge = false;

  void _reset() {
    if (_dragDx != 0 || _fromEdge) {
      setState(() {
        _dragDx = 0;
        _fromEdge = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final offset = _dragDx.clamp(0.0, width * 0.45);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (d) {
        _fromEdge = d.globalPosition.dx <= 40;
        _dragDx = 0;
      },
      onHorizontalDragUpdate: (d) {
        if (!_fromEdge) return;
        final dx = d.delta.dx;
        if (dx > 0) {
          setState(() => _dragDx += dx);
        }
      },
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (_fromEdge && (_dragDx > 60 || v > 400)) {
          widget.onBack();
        }
        _reset();
      },
      onHorizontalDragCancel: _reset,
      child: Transform.translate(
        offset: Offset(offset, 0),
        child: widget.child,
      ),
    );
  }
}
