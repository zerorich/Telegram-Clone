import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:telegramclone/data/models/message.dart';

/// Action callbacks invoked from [showMessageActionMenu]. Implementors decide
/// whether to forward to a remote API, copy to clipboard, etc.
class MessageActions {
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onSaveToFavorites;
  final VoidCallback? onTogglePin;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  MessageActions({
    this.onReply,
    this.onForward,
    this.onSaveToFavorites,
    this.onTogglePin,
    this.onCopy,
    this.onEdit,
    this.onDelete,
  });
}

/// Opens the Telegram-style context menu for a long-pressed message.
///
/// [isMine] determines which item set to render. [canDelete] disables the
/// delete icon on the bottom row when false (e.g. someone else's message in
/// a direct chat or no admin rights in a group).
Future<void> showMessageActionMenu(
  BuildContext context, {
  required MessageModel message,
  required bool isMine,
  required bool isGroup,
  required bool canDelete,
  required bool canEdit,
  required MessageActions actions,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть меню',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (ctx, _, __) {
      return _MessageActionMenu(
        message: message,
        isMine: isMine,
        isGroup: isGroup,
        canDelete: canDelete,
        canEdit: canEdit,
        actions: actions,
      );
    },
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.95, end: 1.0).animate(curved),
          alignment: Alignment.center,
          child: child,
        ),
      );
    },
  );
}

class _MessageActionMenu extends StatelessWidget {
  const _MessageActionMenu({
    required this.message,
    required this.isMine,
    required this.isGroup,
    required this.canDelete,
    required this.canEdit,
    required this.actions,
  });

  final MessageModel message;
  final bool isMine;
  final bool isGroup;
  final bool canDelete;
  final bool canEdit;
  final MessageActions actions;

  @override
  Widget build(BuildContext context) {
    // Wrap in a transparent Material so Text widgets inherit a proper
    // DefaultTextStyle from the theme. Without this, the menu (rendered via
    // showGeneralDialog into an overlay route with no Material ancestor)
    // shows the yellow double-underline dev-time hint on every Text.
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _panel(child: _buildItems(context)),
                  const SizedBox(height: 10),
                  _panel(child: _buildIconRow(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }

  Widget _buildItems(BuildContext context) {
    final items = <Widget>[];

    final statusLine = _statusLine();
    if (statusLine != null) {
      items.add(statusLine);
      items.add(_divider());
    }

    if (isMine) {
      items.add(_item(
        context,
        icon: Icons.forward_outlined,
        label: 'Переслать',
        onTap: actions.onForward,
      ));
      items.add(_item(
        context,
        icon: Icons.bookmark_border,
        label: 'Сохранить',
        onTap: actions.onSaveToFavorites,
      ));
      items.add(_item(
        context,
        icon: message.isPinned
            ? Icons.push_pin
            : Icons.push_pin_outlined,
        label: message.isPinned ? 'Открепить' : 'Закрепить',
        onTap: actions.onTogglePin,
      ));
    } else {
      items.add(_item(
        context,
        icon: Icons.bookmark_border,
        label: 'Сохранить',
        onTap: actions.onSaveToFavorites,
      ));
      items.add(_item(
        context,
        icon: message.isPinned
            ? Icons.push_pin
            : Icons.push_pin_outlined,
        label: message.isPinned ? 'Открепить' : 'Закрепить',
        onTap: actions.onTogglePin,
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: items,
    );
  }

  Widget? _statusLine() {
    if (!isMine) return null;
    final ts = DateFormat('h:mm:ss a').format(message.createdAt.toLocal());
    String text;
    IconData icon;
    if (isGroup) {
      if (message.isRead) {
        text = 'прочитано';
        icon = Icons.done_all;
      } else {
        text = 'доставлено';
        icon = Icons.done;
      }
    } else {
      if (message.isRead) {
        text = 'прочитано в $ts';
        icon = Icons.done_all;
      } else {
        text = 'доставлено в $ts';
        icon = Icons.done;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white60),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 0.5,
        color: Colors.white.withValues(alpha: 0.08),
      );

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    final fg = color ?? Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                Navigator.of(context).pop();
                onTap();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconRow(BuildContext context) {
    final iconButtons = <Widget>[];

    iconButtons.add(_iconBtn(
      context,
      icon: Icons.reply,
      tooltip: 'Ответить',
      onTap: actions.onReply,
    ));

    if (canDelete) {
      iconButtons.add(_iconBtn(
        context,
        icon: Icons.delete_outline,
        tooltip: 'Удалить',
        onTap: actions.onDelete,
      ));
    }

    iconButtons.add(_iconBtn(
      context,
      icon: Icons.copy_outlined,
      tooltip: 'Копировать',
      onTap: actions.onCopy,
    ));

    if (isMine && canEdit) {
      iconButtons.add(_iconBtn(
        context,
        icon: Icons.edit_outlined,
        tooltip: 'Изменить',
        onTap: actions.onEdit,
      ));
    } else {
      iconButtons.add(_iconBtn(
        context,
        icon: Icons.forward_outlined,
        tooltip: 'Переслать',
        onTap: actions.onForward,
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: iconButtons,
      ),
    );
  }

  Widget _iconBtn(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white, size: 22),
      onPressed: onTap == null
          ? null
          : () {
              Navigator.of(context).pop();
              onTap();
            },
    );
  }
}

/// Convenience copier — extracted so callers don't need to import Clipboard.
Future<void> copyMessageText(MessageModel msg) async {
  final t = msg.content ?? '';
  if (t.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: t));
}
