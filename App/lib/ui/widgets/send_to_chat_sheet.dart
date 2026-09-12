import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telegramclone/core/error_utils.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/chats_provider.dart';
import 'package:telegramclone/providers/messages_provider.dart';
import 'package:telegramclone/ui/widgets/avatar_widget.dart';

Future<void> showSendCaptureSheet(
  BuildContext context,
  WidgetRef ref, {
  required String filePath,
}) async {
  final userId = ref.read(authProvider).user?.id ?? '';
  final chats = ref.read(chatsListProvider).valueOrNull ?? const [];
  final targets = chats.where((c) => !c.isSaved).toList();

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.tileHighlight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Отправить фото',
              style: TextStyle(
                color: ctx.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (targets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Нет чатов для отправки',
                style: TextStyle(color: ctx.subtitleColor),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: targets.length,
                itemBuilder: (_, i) {
                  final chat = targets[i];
                  return ListTile(
                    leading: AvatarWidget(
                      imageUrl: chat.fullAvatarUrl,
                      name: chat.displayTitle(userId),
                      size: 40,
                    ),
                    title: Text(
                      chat.displayTitle(userId),
                      style: TextStyle(color: ctx.primaryText),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await ref.read(messagesProvider(chat.id).notifier).sendMedia(
                              type: 'image',
                              path: filePath,
                            );
                        if (context.mounted) context.push('/chat/${chat.id}');
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(friendlyError(e))),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}
