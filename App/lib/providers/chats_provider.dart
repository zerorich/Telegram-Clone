import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telegramclone/core/di.dart';
import 'package:telegramclone/data/models/chat.dart';
import 'package:telegramclone/data/models/message.dart';
import 'package:telegramclone/data/repositories/chat_repository.dart';

class ChatsListNotifier extends StateNotifier<AsyncValue<List<ChatModel>>> {
  final ChatRepository _repo;
  final Ref _ref;

  ChatsListNotifier(this._repo, this._ref)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      state = const AsyncValue.loading();
    } else {
      final cached = await _repo.readCachedChats();
      if (cached.isNotEmpty && !_cacheMissingMembers(cached)) {
        state = AsyncValue.data(cached);
      } else {
        state = const AsyncValue.loading();
      }
    }

    try {
      final chats = await _repo.fetchChatsFromNetwork();
      state = AsyncValue.data(chats);
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void onNewMessage(Map<String, dynamic> data) {
    final msg = MessageModel.fromJson(data);
    state.whenData((chats) {
      final idx = chats.indexWhere((c) => c.id == msg.chatId);
      if (idx >= 0) {
        final updated = chats[idx].copyWith(
          lastMessage: msg,
          unreadCount: chats[idx].unreadCount + 1,
        );
        final list = [...chats]..removeAt(idx)..insert(0, updated);
        state = AsyncValue.data(list);
        _repo.updateCachedChat(updated);
      } else {
        load(refresh: true);
      }
    });
  }

  void clearUnread(String chatId) {
    state.whenData((chats) {
      final idx = chats.indexWhere((c) => c.id == chatId);
      if (idx >= 0) {
        final list = [...chats];
        list[idx] = list[idx].copyWith(unreadCount: 0);
        state = AsyncValue.data(list);
      }
    });
  }

  void onMessageChanged(MessageModel msg) {
    state.whenData((chats) {
      final idx = chats.indexWhere((c) => c.id == msg.chatId);
      if (idx < 0) return;
      final last = chats[idx].lastMessage;
      if (last?.id != msg.id) return;
      final list = [...chats];
      list[idx] = chats[idx].copyWith(lastMessage: msg);
      state = AsyncValue.data(list);
      _repo.updateCachedChat(list[idx]);
    });
  }

  /// Updates read checkmarks on the last outgoing message in the chat list.
  void onMessageRead({
    required String chatId,
    required String readerId,
    required String currentUserId,
  }) {
    if (readerId == currentUserId) return;
    state.whenData((chats) {
      final idx = chats.indexWhere((c) => c.id == chatId);
      if (idx < 0) return;
      final last = chats[idx].lastMessage;
      if (last == null || last.senderId != currentUserId) return;
      final list = [...chats];
      list[idx] = list[idx].copyWith(lastMessage: last.copyWith(isRead: true));
      state = AsyncValue.data(list);
    });
  }

  bool _cacheMissingMembers(List<ChatModel> chats) {
    return chats.any(
      (c) => c.type == ChatType.direct && c.members.isEmpty,
    );
  }
}

final chatsListProvider =
    StateNotifierProvider<ChatsListNotifier, AsyncValue<List<ChatModel>>>((ref) {
  return ChatsListNotifier(ref.watch(chatRepositoryProvider), ref);
});

final chatDetailProvider =
    FutureProvider.family<ChatDetail, String>((ref, chatId) async {
  return ref.watch(chatRepositoryProvider).getChat(chatId);
});
