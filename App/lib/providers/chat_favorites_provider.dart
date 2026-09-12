import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telegramclone/data/models/chat.dart';
import 'package:telegramclone/data/models/message.dart';
import 'package:telegramclone/providers/chats_provider.dart';
import 'package:telegramclone/providers/messages_provider.dart';

/// Forwards [message] to the Saved Messages chat.
Future<MessageModel?> saveMessageToFavorites(
  WidgetRef ref, {
  required String sourceChatId,
  required MessageModel message,
}) async {
  final chats = ref.read(chatsListProvider).valueOrNull ?? const [];
  ChatModel? saved;
  for (final c in chats) {
    if (c.isSaved) {
      saved = c;
      break;
    }
  }
  if (saved == null) return null;
  return ref.read(messagesProvider(sourceChatId).notifier).forwardTo(
        targetChatId: saved.id,
        messageId: message.id,
      );
}
