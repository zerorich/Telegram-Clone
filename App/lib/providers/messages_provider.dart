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

  const MessagesState({
    this.messages = const [],
    this.nextCursor,
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  MessagesState copyWith({
    List<MessageModel>? messages,
    String? nextCursor,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      nextCursor: nextCursor ?? this.nextCursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
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
    final cached = await _repo.getCached(chatId);
    if (cached.isNotEmpty) {
      state = MessagesState(messages: _sort(cached), hasMore: true);
    }
    try {
      final page = await _repo.fetchMessages(chatId);
      final merged = _merge(cached, page.messages);
      state = MessagesState(
        messages: merged,
        nextCursor: page.nextCursor,
        hasMore: page.nextCursor != null && page.nextCursor!.isNotEmpty,
      );
      _repo.cacheMessages(chatId, merged);
    } catch (_) {}
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
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
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
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

  Future<MessageModel?> sendText(String content, {String? replyToId}) async {
    try {
      final msg = await _repo.sendText(chatId, content: content, replyToId: replyToId);
      _addMessage(msg);
      return msg;
    } catch (_) {
      return null;
    }
  }

  Future<MessageModel?> sendMedia({
    required String type,
    required String path,
    int? durationSec,
    String? replyToId,
  }) async {
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
    } catch (_) {
      return null;
    }
  }

  void _addMessage(MessageModel msg) {
    if (state.messages.any((m) => m.id == msg.id)) return;
    state = state.copyWith(messages: _sort([...state.messages, msg]));
    _repo.cacheMessages(chatId, state.messages);
    _ref.read(chatsListProvider.notifier).onNewMessage({
      'id': msg.id,
      'chat_id': msg.chatId,
      'sender_id': msg.senderId,
      'type': msg.type.name,
      'content': msg.content,
      'media_url': msg.mediaUrl,
      'duration_sec': msg.durationSec,
      'reply_to_id': msg.replyToId,
      'is_edited': msg.isEdited,
      'is_deleted': msg.isDeleted,
      'created_at': msg.createdAt.toIso8601String(),
    });
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
    final existing = state.messages[idx];
    if (existing.content == msg.content &&
        existing.isEdited == msg.isEdited &&
        existing.isDeleted == msg.isDeleted) {
      return;
    }
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
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    try {
      final msg = await _repo.deleteMessage(chatId, messageId);
      _applyMessagePatch(msg);
      return true;
    } catch (_) {
      return false;
    }
  }

  void onMessageRead(Map<String, dynamic> data) {
    final messageId = data['message_id']?.toString();
    final readerId = data['user_id']?.toString();
    final me = _ref.read(authProvider).user?.id;
    if (messageId == null || me == null || readerId == null) return;
    // Read receipts apply to our outgoing messages when someone else reads them.
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

  /// Notifies server that messages from others up to [latest] were read.
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
}

final messagesProvider =
    StateNotifierProvider.autoDispose.family<MessagesNotifier, MessagesState, String>(
  (ref, chatId) {
    return MessagesNotifier(ref.watch(messageRepositoryProvider), chatId, ref);
  },
);

final replyToProvider = StateProvider.family<MessageModel?, String>((ref, _) => null);
