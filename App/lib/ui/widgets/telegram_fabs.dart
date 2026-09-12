import 'package:flutter/material.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/core/theme_extensions.dart';

class TelegramFabs extends StatelessWidget {
  const TelegramFabs({
    super.key,
    required this.onEdit,
    required this.onCamera,
  });

  final VoidCallback onEdit;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Semantics(
          label: 'Новое сообщение',
          button: true,
          child: Material(
          color: context.tileHighlight,
          elevation: 4,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(28),
            child: const SizedBox(
              width: 46,
              height: 46,
              child: Icon(Icons.edit_outlined, color: Colors.white, size: 22),
            ),
          ),
        ),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: 'Камера',
          button: true,
          child: Material(
          color: AppColors.teal,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onCamera,
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(
              width: 56,
              height: 56,
              child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
        ),
      ],
    );
  }
}
