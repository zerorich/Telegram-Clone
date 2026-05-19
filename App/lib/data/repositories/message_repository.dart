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
      messages
          .map((m) => {
                'id': m.id,
                'chat_id': m.chatId,
                'sender_id': m.senderId,
                'type': m.type.name,
                'content': m.content,
                'media_url': m.mediaUrl,
                'duration_sec': m.durationSec,
                'reply_to_id': m.replyToId,
                'is_edited': m.isEdited,
                'is_deleted': m.isDeleted,
                'created_at': m.createdAt.toIso8601String(),
              })
          .toList(),
    );
  }

  Future<MessagesPage> fetchMessages(
    String chatId, {
    String? cursor,
    int limit = 50,
  }) =>
      _api.listMessages(chatId, cursor: cursor, limit: limit);

  Future<MessageModel> sendText(String chatId,
          {required String content, String? replyToId}) =>
      _api.sendText(chatId, content: content, replyToId: replyToId);

  Future<MessageModel> sendMedia(String chatId,
          {required String type,
          required String filePath,
          int? durationSec,
          String? replyToId}) =>
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
}
