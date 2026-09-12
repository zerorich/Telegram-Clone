import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telegramclone/data/models/chat_member.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/chats_provider.dart';

/// Resolves the current user's membership in a chat (for admin checks, etc.).
final myChatMemberProvider =
    Provider.autoDispose.family<ChatMemberModel?, String>((ref, chatId) {
  final myId = ref.watch(authProvider).user?.id;
  if (myId == null) return null;
  final chats = ref.watch(chatsListProvider).valueOrNull ?? const [];
  for (final c in chats) {
    if (c.id != chatId) continue;
    for (final m in c.members) {
      if (m.userId == myId) return m;
    }
  }
  return null;
});

bool isAdminOrOwner(ChatMemberModel? member) {
  if (member == null) return false;
  return member.role == MemberRole.admin || member.role == MemberRole.owner;
}
