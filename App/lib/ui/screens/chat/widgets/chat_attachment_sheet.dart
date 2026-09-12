import 'package:flutter/material.dart';
import 'package:telegramclone/core/theme_extensions.dart';

typedef AttachmentAction = void Function();

Future<void> showChatAttachmentSheet(
  BuildContext context, {
  required AttachmentAction onPhoto,
  required AttachmentAction onVideo,
  required AttachmentAction onFile,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.tileHighlight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ctx.subtitleColor.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withValues(alpha: 0.2),
              ),
              child: const Icon(Icons.image_rounded, color: Colors.blue),
            ),
            title: Text('Фото', style: TextStyle(color: ctx.primaryText, fontSize: 16)),
            subtitle: Text(
              'Выбрать из галереи',
              style: TextStyle(color: ctx.subtitleColor, fontSize: 13),
            ),
            onTap: () {
              Navigator.pop(ctx);
              onPhoto();
            },
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withValues(alpha: 0.2),
              ),
              child: const Icon(Icons.videocam_rounded, color: Colors.purple),
            ),
            title: Text('Видео', style: TextStyle(color: ctx.primaryText, fontSize: 16)),
            subtitle: Text(
              'Выбрать видео из галереи',
              style: TextStyle(color: ctx.subtitleColor, fontSize: 13),
            ),
            onTap: () {
              Navigator.pop(ctx);
              onVideo();
            },
          ),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withValues(alpha: 0.2),
              ),
              child: const Icon(Icons.insert_drive_file_rounded, color: Colors.orange),
            ),
            title: Text('Файл', style: TextStyle(color: ctx.primaryText, fontSize: 16)),
            subtitle: Text(
              'Выбрать файл',
              style: TextStyle(color: ctx.subtitleColor, fontSize: 13),
            ),
            onTap: () {
              Navigator.pop(ctx);
              onFile();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
