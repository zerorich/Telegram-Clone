import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telegramclone/core/di.dart';
import 'package:telegramclone/data/models/chat.dart';
import 'package:telegramclone/data/models/message.dart';
import 'package:telegramclone/data/repositories/chat_repository.dart';

class ChatsListNotifier extends StateNotifier<AsyncValue<List<ChatModel>>> {
  final ChatRepository _repo;
  // ignore: unused_field
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
      final savedCached = await _repo.readCachedSaved();
      final merged = _withSaved(cached, savedCached);
      if (merged.isNotEmpty && !_cacheMissingMembers(merged)) {
        state = AsyncValue.data(_sortChats(merged));
      } else {
        state = const AsyncValue.loading();
      }
    }

    try {
      final chats = await _repo.fetchChatsFromNetwork();
      // The chats endpoint may already include the saved chat — but per
      // contract we should not depend on that. Fetch it separately if absent.
      ChatModel? saved = chats.firstWhere(
        (c) => c.type == ChatType.saved,
        orElse: () => _placeholder(),
      );
      if (saved.id.isEmpty) {
        saved = await _repo.fetchSavedFromNetwork();
      } else {
        await _repo.cacheSaved(saved);
      }
      final list = chats.where((c) => c.type != ChatType.saved).toList();
      state = AsyncValue.data(_sortChats(_withSaved(list, saved)));
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  ChatModel _placeholder() => ChatModel(
        id: '',
        type: ChatType.direct,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  List<ChatModel> _withSaved(List<ChatModel> chats, ChatModel? saved) {
    final base = chats.where((c) => c.type != ChatType.saved).toList();
    if (saved != null && saved.id.isNotEmpty) {
      base.insert(0, saved);
    }
    return base;
  }

  /// Saved chat pinned to top, others sorted by last activity DESC.
  List<ChatModel> _sortChats(List<ChatModel> chats) {
    final saved = chats.where((c) => c.type == ChatType.saved).toList();
    final rest = chats.where((c) => c.type != ChatType.saved).toList()
      ..sort((a, b) {
        final at = a.lastMessage?.createdAt ?? a.createdAt;
        final bt = b.lastMessage?.createdAt ?? b.createdAt;
        return bt.compareTo(at);
      });
    return [...saved, ...rest];
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
        final list = [...chats]..[idx] = updated;
        state = AsyncValue.data(_sortChats(list));
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

  /// WS event: chat history was cleared server-side.
  void onChatCleared(String chatId) {
    state.whenData((chats) {
      final idx = chats.indexWhere((c) => c.id == chatId);
      if (idx < 0) return;
      final list = [...chats];
      list[idx] = list[idx].copyWith(clearLastMessage: true, unreadCount: 0);
      state = AsyncValue.data(list);
      _repo.updateCachedChat(list[idx]);
    });
  }

  /// WS event: chat was deleted server-side or via own action.
  void onChatDeleted(String chatId) {
    state.whenData((chats) {
      final list = chats.where((c) => c.id != chatId).toList();
      state = AsyncValue.data(list);
    });
    _repo.removeCachedChat(chatId);
  }

  /// WS event or own action: mute state changed.
  void onChatMuted(String chatId, DateTime? until) {
    state.whenData((chats) {
      final idx = chats.indexWhere((c) => c.id == chatId);
      if (idx < 0) return;
      final list = [...chats];
      list[idx] = list[idx].copyWith(
        mutedUntil: until,
        clearMutedUntil: until == null,
      );
      state = AsyncValue.data(list);
      _repo.updateCachedChat(list[idx]);
    });
  }

  /// Optimistically updates the chat's last message (used after pin change so
  /// chat list refresh isn't required).
  void patchLastMessage(MessageModel msg) {
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

  Future<void> mute(String chatId, {DateTime? until}) async {
    await _repo.mute(chatId, until: until);
    onChatMuted(chatId, until ?? DateTime.utc(9999));
  }

  Future<void> unmute(String chatId) async {
    await _repo.unmute(chatId);
    onChatMuted(chatId, null);
  }

  Future<void> deleteChat(String chatId) async {
    await _repo.deleteChat(chatId);
    onChatDeleted(chatId);
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
