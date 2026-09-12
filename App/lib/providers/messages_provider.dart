import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telegramclone/core/di.dart';
import 'package:telegramclone/data/models/message.dart';
import 'package:telegramclone/data/repositories/message_repository.dart';
import 'package:telegramclone/providers/active_chat_provider.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/chats_provider.dart';
import 'package:telegramclone/providers/ws_provider.dart';

class MessagesState {
  final List<MessageModel> messages;
  final String? nextCursor;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isInitialLoading;
  final Object? loadError;
  final Object? sendError;

  const MessagesState({
    this.messages = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.isInitialLoading = false,
    this.loadError,
    this.sendError,
  });

  MessagesState copyWith({
    List<MessageModel>? messages,
    String? nextCursor,
    bool? isLoadingMore,
    bool? hasMore,
    bool? isInitialLoading,
    Object? loadError,
    Object? sendError,
    bool clearNextCursor = false,
    bool clearLoadError = false,
    bool clearSendError = false,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      sendError: clearSendError ? null : (sendError ?? this.sendError),
    );
  }
}

class MessagesNotifier extends StateNotifier<MessagesState> {
  final MessageRepository _repo;
  final String chatId;
  final Ref _ref;
  String? _lastMarkedReadId;

  MessagesNotifier(this._repo, this.chatId, this._ref)
      : super(const MessagesState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(
      isInitialLoading: true,
      clearLoadError: true,
    );
    final cached = await _repo.getCached(chatId);
    if (cached.isNotEmpty) {
      state = MessagesState(
        messages: _sort(cached),
        hasMore: true,
        isInitialLoading: true,
      );
    }
    try {
      final page = await _repo.fetchMessages(chatId);
      final merged = _merge(cached, page.messages);
      state = MessagesState(
        messages: merged,
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null && page.nextCursor!.isNotEmpty,
      );
      await _repo.cacheMessages(chatId, merged);
    } catch (e) {
      state = state.copyWith(
        isInitialLoading: false,
        loadError: e,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearLoadError: true);
    try {
      final page = await _repo.fetchMessages(chatId, cursor: state.nextCursor);
      final merged = _merge(state.messages, page.messages);
      state = MessagesState(
        messages: merged,
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null && page.nextCursor!.isNotEmpty,
        isLoadingMore: false,
      );
      await _repo.cacheMessages(chatId, merged);
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, loadError: e);
    }
  }

  List<MessageModel> _merge(List<MessageModel> existing, List<MessageModel> incoming) {
    final map = {for (final m in existing) m.id: m};
    for (final m in incoming) {
      map[m.id] = m;
    }
    return _sort(map.values.toList());
  }

  List<MessageModel> _sort(List<MessageModel> list) {
    final sorted = [...list]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  Future<MessageModel> sendText(String content, {String? replyToId}) async {
    state = state.copyWith(clearSendError: true);
    try {
      final msg = await _repo.sendText(chatId, content: content, replyToId: replyToId);
      _addMessage(msg);
      return msg;
    } catch (e) {
      state = state.copyWith(sendError: e);
      rethrow;
    }
  }

  Future<MessageModel> sendMedia({
    required String type,
    required String path,
    int? durationSec,
    String? replyToId,
  }) async {
    state = state.copyWith(clearSendError: true);
    try {
      final msg = await _repo.sendMedia(
        chatId,
        type: type,
        filePath: path,
        durationSec: durationSec,
        replyToId: replyToId,
      );
      _addMessage(msg);
      return msg;
    } catch (e) {
      state = state.copyWith(sendError: e);
      rethrow;
    }
  }

  void _addMessage(MessageModel msg) {
    if (state.messages.any((m) => m.id == msg.id)) return;
    state = state.copyWith(messages: _sort([...state.messages, msg]));
    _repo.cacheMessages(chatId, state.messages);
    _ref.read(chatsListProvider.notifier).onNewMessage(msg.toJson());
  }

  void onNewMessage(Map<String, dynamic> data) {
    final msg = MessageModel.fromJson(data);
    if (msg.chatId != chatId) return;
    _addMessage(msg);
  }

  void onMessageUpdated(Map<String, dynamic> data) {
    final msg = MessageModel.fromJson(data);
    if (msg.chatId != chatId) return;
    final idx = state.messages.indexWhere((m) => m.id == msg.id);
    if (idx < 0) return;
    _applyMessagePatch(msg);
  }

  void onMessageDeleted(Map<String, dynamic> data) {
    final msg = MessageModel.fromJson(data);
    if (msg.chatId != chatId) return;
    final idx = state.messages.indexWhere((m) => m.id == msg.id);
    if (idx < 0) return;
    if (state.messages[idx].isDeleted) return;
    _applyMessagePatch(msg);
  }

  /// Used by ws_provider for `message.pinned` / `message.unpinned` events.
  void onMessagePinned(Map<String, dynamic> data) {
    final msg = MessageModel.fromJson(data);
    if (msg.chatId != chatId) return;
    final idx = state.messages.indexWhere((m) => m.id == msg.id);
    if (idx < 0) return;
    _applyMessagePatch(msg);
    _ref.read(pinnedMessagesProvider(chatId).notifier).upsert(msg);
  }

  /// Server signalled the entire history was wiped.
  void onChatCleared() {
    state = const MessagesState(
      messages: [],
      hasMore: false,
    );
    _repo.clearCachedMessages(chatId);
    _ref.read(pinnedMessagesProvider(chatId).notifier).clear();
  }

  void _applyMessagePatch(MessageModel msg) {
    state = state.copyWith(
      messages: state.messages.map((m) => m.id == msg.id ? msg : m).toList(),
    );
    _repo.cacheMessages(chatId, state.messages);
    Future.microtask(() {
      _ref.read(chatsListProvider.notifier).onMessageChanged(msg);
    });
  }

  Future<bool> editText(String messageId, String content) async {
    try {
      final msg = await _repo.editText(chatId, messageId, content: content);
      _applyMessagePatch(msg);
      return true;
    } catch (e) {
      state = state.copyWith(sendError: e);
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    try {
      final msg = await _repo.deleteMessage(chatId, messageId);
      _applyMessagePatch(msg);
      return true;
    } catch (e) {
      state = state.copyWith(sendError: e);
      return false;
    }
  }

  Future<MessageModel?> forwardTo({
    required String targetChatId,
    required String messageId,
  }) async {
    try {
      final msg = await _repo.forward(
        targetChatId: targetChatId,
        sourceChatId: chatId,
        messageId: messageId,
      );
      if (_ref.exists(messagesProvider(targetChatId))) {
        _ref
            .read(messagesProvider(targetChatId).notifier)
            ._addMessage(msg);
      } else {
        _ref.read(chatsListProvider.notifier).onNewMessage(msg.toJson());
      }
      return msg;
    } catch (e) {
      state = state.copyWith(sendError: e);
      return null;
    }
  }

  Future<bool> togglePin(MessageModel msg) async {
    try {
      final updated = msg.isPinned
          ? await _repo.unpin(chatId, msg.id)
          : await _repo.pin(chatId, msg.id);
      _applyMessagePatch(updated);
      _ref.read(pinnedMessagesProvider(chatId).notifier).upsert(updated);
      return true;
    } catch (e) {
      state = state.copyWith(sendError: e);
      return false;
    }
  }

  Future<bool> clearHistory() async {
    try {
      await _repo.clearHistory(chatId);
      onChatCleared();
      _ref.read(chatsListProvider.notifier).onChatCleared(chatId);
      return true;
    } catch (e) {
      state = state.copyWith(loadError: e);
      return false;
    }
  }

  Future<List<MessageModel>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      return await _repo.search(chatId, query: q);
    } catch (e) {
      state = state.copyWith(loadError: e);
      rethrow;
    }
  }

  void onMessageRead(Map<String, dynamic> data) {
    final messageId = data['message_id']?.toString();
    final readerId = data['user_id']?.toString();
    final me = _ref.read(authProvider).user?.id;
    if (messageId == null || me == null || readerId == null) return;
    if (readerId == me) return;

    MessageModel? anchor;
    for (final m in state.messages) {
      if (m.id == messageId) {
        anchor = m;
        break;
      }
    }
    if (anchor == null) return;
    final readUpTo = anchor.createdAt;

    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.senderId == me && !m.createdAt.isAfter(readUpTo)) {
          return m.copyWith(isRead: true);
        }
        return m;
      }).toList(),
    );

    _ref.read(chatsListProvider.notifier).onMessageRead(
          chatId: chatId,
          readerId: readerId,
          currentUserId: me,
        );
  }

  void markReadUpTo(String currentUserId) {
    if (currentUserId.isEmpty) return;
    if (_ref.read(activeChatIdProvider) != chatId) return;

    final fromOthers = state.messages
        .where((m) => m.senderId != currentUserId)
        .toList();
    if (fromOthers.isEmpty) return;

    final latest = fromOthers.reduce(
      (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
    );
    if (latest.id == _lastMarkedReadId) return;
    _lastMarkedReadId = latest.id;

    _ref.read(wsServiceProvider).sendRead(chatId, latest.id);
  }

  Future<void> loadAllHistory({int maxBatches = 10}) async {
    var batches = 0;
    while (state.hasMore && batches < maxBatches) {
      await loadMore();
      if (state.loadError != null) break;
      batches += 1;
    }
  }
}

final messagesProvider =
    StateNotifierProvider.autoDispose.family<MessagesNotifier, MessagesState, String>(
  (ref, chatId) {
    return MessagesNotifier(ref.watch(messageRepositoryProvider), chatId, ref);
  },
);

final replyToProvider = StateProvider.family<MessageModel?, String>((ref, _) => null);

class PinnedMessagesNotifier extends StateNotifier<List<MessageModel>> {
  PinnedMessagesNotifier(this._repo, this.chatId) : super(const []) {
    _load();
  }

  final MessageRepository _repo;
  final String chatId;
  Object? lastError;

  Future<void> _load() async {
    try {
      final list = await _repo.getPinned(chatId);
      lastError = null;
      state = list;
    } catch (e) {
      lastError = e;
      state = const [];
    }
  }

  Future<void> refresh() => _load();

  void upsert(MessageModel msg) {
    final without = state.where((m) => m.id != msg.id).toList();
    if (msg.isPinned && !msg.isDeleted) {
      without.insert(0, msg);
    }
    without.sort((a, b) {
      final ap = a.pinnedAt ?? a.createdAt;
      final bp = b.pinnedAt ?? b.createdAt;
      return bp.compareTo(ap);
    });
    state = without;
  }

  void clear() => state = const [];
}

final pinnedMessagesProvider = StateNotifierProvider.autoDispose
    .family<PinnedMessagesNotifier, List<MessageModel>, String>((ref, chatId) {
  return PinnedMessagesNotifier(ref.watch(messageRepositoryProvider), chatId);
});
