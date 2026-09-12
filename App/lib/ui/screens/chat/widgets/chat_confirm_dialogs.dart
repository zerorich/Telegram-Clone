import 'package:flutter/material.dart';
import 'package:telegramclone/core/theme_extensions.dart';

Future<bool> confirmClearHistory(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.tileHighlight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Очистить историю',
        style: TextStyle(color: ctx.primaryText, fontWeight: FontWeight.w600),
      ),
      content: Text(
        'Очистить всю историю сообщений? Это действие нельзя отменить.',
        style: TextStyle(color: ctx.primaryText.withValues(alpha: 0.7), height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Отмена', style: TextStyle(color: ctx.subtitleColor)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Очистить'),
        ),
      ],
    ),
  ).then((v) => v ?? false);
}

Future<bool> confirmDeleteChat(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ctx.tileHighlight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Удалить чат',
        style: TextStyle(color: ctx.primaryText, fontWeight: FontWeight.w600),
      ),
      content: Text(
        'Удалить чат? Сообщения будут удалены.',
        style: TextStyle(color: ctx.primaryText.withValues(alpha: 0.7), height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Отмена', style: TextStyle(color: ctx.subtitleColor)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Удалить'),
        ),
      ],
    ),
  ).then((v) => v ?? false);
}
