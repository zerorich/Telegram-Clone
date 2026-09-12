import 'package:flutter/material.dart';
import 'package:telegramclone/core/theme_extensions.dart';

/// iOS-style back gesture from the left edge.
///
/// Uses [Listener] (raw pointer events) instead of [GestureDetector]
/// so it is NOT subject to the gesture arena — works even when a
/// [ListView] or any other scroll view is underneath.
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

class _SwipeBackDetectorState extends State<SwipeBackDetector>
    with SingleTickerProviderStateMixin {
  // The pointer id we are currently tracking; null = not tracking.
  int? _activePointer;
  double _startX = 0;
  double _dragDx = 0; // how far rightward the screen has moved

  // Velocity estimation (pixels/second)
  double _lastX = 0;
  int _lastTimeMs = 0;
  double _velocityPxS = 0;

  // Snap-back animation when the user releases without crossing the threshold
  late final AnimationController _snapCtrl;
  late Animation<double> _snapAnim;
  bool _snapping = false;

  /// Only track touches that start inside this many pixels from the left edge.
  static const double _edgeZone = 50.0;

  /// Threshold: drag at least this fraction of screen width to trigger.
  static const double _distRatio = 0.25;

  /// OR use this minimum velocity (px/s) to trigger.
  static const double _velocityMin = 400.0;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  // ── pointer handlers ────────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    // Ignore if already snapping back or tracking another finger
    if (_activePointer != null || _snapping) return;
    if (e.position.dx > _edgeZone) return; // not a left-edge touch

    _activePointer = e.pointer;
    _startX = e.position.dx;
    _dragDx = 0;
    _lastX = e.position.dx;
    _lastTimeMs = DateTime.now().millisecondsSinceEpoch;
    _velocityPxS = 0;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _activePointer) return;

    // Update velocity (exponential moving average)
    final now = DateTime.now().millisecondsSinceEpoch;
    final dt = now - _lastTimeMs;
    if (dt > 0) {
      final instant = (e.position.dx - _lastX) / dt * 1000;
      _velocityPxS = _velocityPxS * 0.55 + instant * 0.45;
    }
    _lastX = e.position.dx;
    _lastTimeMs = now;

    final dx = e.position.dx - _startX;
    if (dx <= 0) return; // only allow rightward movement

    final width = MediaQuery.sizeOf(context).width;
    setState(() {
      _dragDx = dx.clamp(0.0, width * 0.55);
    });
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _activePointer) return;
    _finish(e.position.dx);
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer != _activePointer) return;
    _snapBack();
  }

  void _finish(double upX) {
    final width = MediaQuery.sizeOf(context).width;
    final dx = upX - _startX;

    if (dx > width * _distRatio || _velocityPxS > _velocityMin) {
      // ✅ Navigate back
      _activePointer = null;
      setState(() => _dragDx = 0);
      widget.onBack();
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    _activePointer = null;
    if (_dragDx <= 0) {
      setState(() => _dragDx = 0);
      return;
    }

    final from = _dragDx;
    _snapAnim = Tween<double>(begin: from, end: 0).animate(
      CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOutCubic),
    );
    _snapping = true;
    _snapCtrl
      ..reset()
      ..forward().then((_) {
        if (mounted) setState(() => _snapping = false);
      });
  }

  // ── build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Listener(
      // Listener bypasses the gesture arena → always receives events.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedBuilder(
        animation: _snapCtrl,
        builder: (context, child) {
          final offset =
              _snapping ? _snapAnim.value : _dragDx;
          final progress = (offset / (width * 0.55)).clamp(0.0, 1.0);

          return Stack(
            children: [
              // ── The screen content, shifted right ──
              Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              ),

              // ── Left overlay: darkening + arrow indicator ──
              if (offset > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: offset,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black
                                .withValues(alpha: 0.28 * progress),
                            Colors.transparent,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.only(
                        left: (offset - 36).clamp(6.0, 20.0),
                      ),
                      child: Opacity(
                        opacity: (progress * 3.0).clamp(0.0, 1.0),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.tileHighlight.withValues(alpha: 0.88),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Right-edge depth shadow ──
              if (offset > 0)
                Positioned(
                  left: offset,
                  top: 0,
                  bottom: 0,
                  width: 18,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black
                                .withValues(alpha: 0.24 * progress),
                            Colors.transparent,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}
