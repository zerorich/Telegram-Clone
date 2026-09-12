import 'package:hive_flutter/hive_flutter.dart';
import 'package:telegramclone/data/api/messages_api.dart';
import 'package:telegramclone/data/models/message.dart';

class MessageRepository {
  final MessagesApi _api;
  final Map<String, Box> _boxes = {};

  MessageRepository(this._api);

  String _boxName(String chatId) => 'messages_$chatId';

  Future<Box> _box(String chatId) async {
    final name = _boxName(chatId);
    return _boxes[name] ??= await Hive.openBox(name);
  }

  Future<List<MessageModel>> getCached(String chatId) async {
    final box = await _box(chatId);
    final list = box.get('messages');
    if (list is! List) return [];
    return list.map((e) => MessageModel.fromJson(e)).toList();
  }

  Future<void> cacheMessages(String chatId, List<MessageModel> messages) async {
    final box = await _box(chatId);
    await box.put(
      'messages',
      messages.map((m) => m.toJson(forCache: true)).toList(),
    );
  }

  Future<void> clearCachedMessages(String chatId) async {
    final box = await _box(chatId);
    await box.delete('messages');
  }

  Future<MessagesPage> fetchMessages(
    String chatId, {
    String? cursor,
    int limit = 50,
  }) =>
      _api.listMessages(chatId, cursor: cursor, limit: limit);

  Future<MessageModel> sendText(String chatId,
          {required String content, String? replyToId,}) =>
      _api.sendText(chatId, content: content, replyToId: replyToId);

  Future<MessageModel> sendMedia(String chatId,
          {required String type,
          required String filePath,
          int? durationSec,
          String? replyToId,}) =>
      _api.sendMedia(
        chatId,
        type: type,
        filePath: filePath,
        durationSec: durationSec,
        replyToId: replyToId,
      );

  Future<void> markRead(String chatId, String messageId) =>
      _api.markRead(chatId, messageId);

  Future<MessageModel> editText(
    String chatId,
    String messageId, {
    required String content,
  }) =>
      _api.editText(chatId, messageId, content: content);

  Future<MessageModel> deleteMessage(String chatId, String messageId) =>
      _api.deleteMessage(chatId, messageId);

  Future<MessageModel> forward({
    required String targetChatId,
    required String sourceChatId,
    required String messageId,
  }) =>
      _api.forward(
        targetChatId: targetChatId,
        sourceChatId: sourceChatId,
        messageId: messageId,
      );

  Future<MessageModel> pin(String chatId, String messageId) =>
      _api.pin(chatId, messageId);

  Future<MessageModel> unpin(String chatId, String messageId) =>
      _api.unpin(chatId, messageId);

  Future<List<MessageModel>> getPinned(String chatId) => _api.getPinned(chatId);

  Future<List<MessageModel>> search(
    String chatId, {
    required String query,
    int limit = 50,
  }) =>
      _api.search(chatId, query: query, limit: limit);

  Future<void> clearHistory(String chatId) => _api.clearHistory(chatId);

  /// Wipes cached messages for all chats whose IDs are known to the caller.
  /// Closes and deletes per-chat Hive boxes from disk so they don't leak
  /// across user sessions.
  Future<void> clearAllCaches(Iterable<String> chatIds) async {
    for (final id in chatIds) {
      final name = _boxName(id);
      _boxes.remove(name);
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).close();
      }
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (_) {}
    }
  }
}
