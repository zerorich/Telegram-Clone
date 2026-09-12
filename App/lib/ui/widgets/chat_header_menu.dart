import 'package:flutter/material.dart';

/// Result of [showChatHeaderMenu]. The caller decides what to do for each
/// action.
enum ChatHeaderAction {
  notifications,
  notificationsOn,
  notificationsOffForever,
  notificationsOff1h,
  notificationsOff1d,
  call,
  search,
  scrollToStart,
  clearHistory,
  deleteChat,
}

/// Shows the three-dot menu for the chat header. Anchored to [anchorKey]
/// when given (typically the IconButton's key), otherwise falls back to the
/// top-right of the screen.
Future<void> showChatHeaderMenu(
  BuildContext context, {
  required GlobalKey anchorKey,
  required bool isSaved,
  required bool isMuted,
  required void Function(ChatHeaderAction action) onAction,
}) async {
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  final anchor =
      anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (overlay == null) return;

  Offset topLeft;
  if (anchor != null) {
    final pos = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    topLeft = pos + Offset(0, anchor.size.height);
  } else {
    topLeft = Offset(overlay.size.width - 260, 60);
  }

  final size = overlay.size;
  // Keep menu fully on-screen by clamping the x coordinate.
  const menuWidth = 240.0;
  final clampedLeft =
      topLeft.dx.clamp(8.0, size.width - menuWidth - 8.0).toDouble();

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть меню',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (ctx, _, __) {
      return Stack(
        children: [
          Positioned(
            left: clampedLeft,
            top: topLeft.dy + 4,
            width: menuWidth,
            child: _HeaderMenuPanel(
              isSaved: isSaved,
              isMuted: isMuted,
              onAction: (a) {
                Navigator.of(ctx).pop();
                onAction(a);
              },
            ),
          ),
        ],
      );
    },
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.95, end: 1.0).animate(curved),
          alignment: Alignment.topRight,
          child: child,
        ),
      );
    },
  );
}

class _HeaderMenuPanel extends StatefulWidget {
  const _HeaderMenuPanel({
    required this.isSaved,
    required this.isMuted,
    required this.onAction,
  });

  final bool isSaved;
  final bool isMuted;
  final void Function(ChatHeaderAction action) onAction;

  @override
  State<_HeaderMenuPanel> createState() => _HeaderMenuPanelState();
}

class _HeaderMenuPanelState extends State<_HeaderMenuPanel> {
  bool _showNotifSubmenu = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E).withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: _showNotifSubmenu ? _buildNotifSubmenu() : _buildMain(),
        ),
      ),
    );
  }

  Widget _buildMain() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _item(
          icon: widget.isMuted
              ? Icons.notifications_off_outlined
              : Icons.notifications_outlined,
          label: 'Уведомления',
          trailing: const Icon(Icons.chevron_right,
              color: Colors.white54, size: 20,),
          onTap: () => setState(() => _showNotifSubmenu = true),
        ),
        if (!widget.isSaved)
          _item(
            icon: Icons.call_outlined,
            label: 'Позвонить',
            onTap: () => widget.onAction(ChatHeaderAction.call),
          ),
        _item(
          icon: Icons.search,
          label: 'Поиск',
          onTap: () => widget.onAction(ChatHeaderAction.search),
        ),
        _item(
          icon: Icons.keyboard_double_arrow_up,
          label: 'В начало',
          onTap: () => widget.onAction(ChatHeaderAction.scrollToStart),
        ),
        _item(
          icon: Icons.cleaning_services_outlined,
          label: 'Очистить историю',
          onTap: () => widget.onAction(ChatHeaderAction.clearHistory),
        ),
        if (!widget.isSaved)
          _item(
            icon: Icons.delete_outline,
            label: 'Удалить чат',
            color: Colors.redAccent,
            onTap: () => widget.onAction(ChatHeaderAction.deleteChat),
          ),
      ],
    );
  }

  Widget _buildNotifSubmenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _showNotifSubmenu = false),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(8, 10, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.chevron_left, color: Colors.white70),
                  SizedBox(width: 4),
                  Text(
                    'Уведомления',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        _item(
          icon: Icons.notifications_active_outlined,
          label: 'Включено',
          onTap: () => widget.onAction(ChatHeaderAction.notificationsOn),
        ),
        _item(
          icon: Icons.notifications_off_outlined,
          label: 'Выключено навсегда',
          onTap: () =>
              widget.onAction(ChatHeaderAction.notificationsOffForever),
        ),
        _item(
          icon: Icons.timelapse_outlined,
          label: 'На 1 час',
          onTap: () => widget.onAction(ChatHeaderAction.notificationsOff1h),
        ),
        _item(
          icon: Icons.calendar_today_outlined,
          label: 'На 1 день',
          onTap: () => widget.onAction(ChatHeaderAction.notificationsOff1d),
        ),
      ],
    );
  }

  Widget _item({
    required IconData icon,
    required String label,
    Widget? trailing,
    Color? color,
    required VoidCallback onTap,
  }) {
    final fg = color ?? Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}

