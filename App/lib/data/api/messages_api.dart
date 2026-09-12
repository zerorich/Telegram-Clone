import 'package:dio/dio.dart';
import 'package:telegramclone/core/json_map.dart';
import 'package:telegramclone/data/api/api_helpers.dart';
import 'package:telegramclone/data/models/api_response.dart';
import 'package:telegramclone/data/models/message.dart';

class MessagesPage {
  final List<MessageModel> messages;
  final String? nextCursor;

  MessagesPage({required this.messages, this.nextCursor});
}

class MessagesApi {
  final Dio _dio;

  MessagesApi(this._dio);

  Future<MessagesPage> listMessages(
    String chatId, {
    String? cursor,
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '/api/chats/$chatId/messages',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    final data = asJsonMap(_parseData(res.data));
    final list = parseDataList(data['messages'], MessageModel.fromJson);
    return MessagesPage(
      messages: list,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  Future<MessageModel> sendText(
    String chatId, {
    required String content,
    String? replyToId,
  }) async {
    final res = await _dio.post('/api/chats/$chatId/messages', data: {
      'content': content,
      if (replyToId != null) 'reply_to_id': replyToId,
    },);
    return MessageModel.fromJson(_parseData(res.data));
  }

  Future<MessageModel> sendMedia(
    String chatId, {
    required String type,
    required String filePath,
    int? durationSec,
    String? replyToId,
  }) async {
    final filename = type == 'voice' ? 'voice.m4a' : null;
    final form = FormData.fromMap({
      'type': type,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filename,
      ),
      if (durationSec != null) 'duration_sec': durationSec.toString(),
      if (replyToId != null) 'reply_to_id': replyToId,
    });
    final res = await _dio.post('/api/chats/$chatId/messages/media', data: form);
    return MessageModel.fromJson(_parseData(res.data));
  }

  Future<MessageModel> editText(
    String chatId,
    String messageId, {
    required String content,
  }) async {
    final res = await _dio.patch(
      '/api/chats/$chatId/messages/$messageId',
      data: {'content': content},
    );
    return MessageModel.fromJson(_parseData(res.data));
  }

  Future<MessageModel> deleteMessage(String chatId, String messageId) async {
    final res = await _dio.delete('/api/chats/$chatId/messages/$messageId');
    return MessageModel.fromJson(_parseData(res.data));
  }

  Future<void> markRead(String chatId, String messageId) async {
    final res = await _dio.post('/api/chats/$chatId/messages/read', data: {
      'message_id': messageId,
    },);
    _ensureSuccess(res.data);
  }

  /// Forwards [messageId] from [sourceChatId] into [targetChatId].
  Future<MessageModel> forward({
    required String targetChatId,
    required String sourceChatId,
    required String messageId,
  }) async {
    final res = await _dio.post(
      '/api/chats/$targetChatId/messages/forward',
      data: {
        'source_chat_id': sourceChatId,
        'message_id': messageId,
      },
    );
    return MessageModel.fromJson(_parseData(res.data));
  }

  Future<MessageModel> pin(String chatId, String messageId) async {
    final res =
        await _dio.post('/api/chats/$chatId/messages/$messageId/pin');
    return MessageModel.fromJson(_parseData(res.data));
  }

  Future<MessageModel> unpin(String chatId, String messageId) async {
    final res =
        await _dio.delete('/api/chats/$chatId/messages/$messageId/pin');
    return MessageModel.fromJson(_parseData(res.data));
  }

  Future<List<MessageModel>> getPinned(String chatId) async {
    final res = await _dio.get('/api/chats/$chatId/pinned');
    final data = asJsonMap(_parseData(res.data));
    return parseDataList(data['messages'], MessageModel.fromJson);
  }

  Future<List<MessageModel>> search(
    String chatId, {
    required String query,
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '/api/chats/$chatId/messages/search',
      queryParameters: {'q': query, 'limit': limit},
    );
    final data = asJsonMap(_parseData(res.data));
    return parseDataList(data['messages'], MessageModel.fromJson);
  }

  /// Clears all messages in the chat (chat itself remains).
  Future<void> clearHistory(String chatId) async {
    final res = await _dio.delete('/api/chats/$chatId/messages');
    _ensureSuccess(res.data);
  }

  dynamic _parseData(dynamic json) {
    final api = ApiResponse.fromJson(json, null);
    if (!api.success) throw Exception(api.error ?? 'Request failed');
    return api.data;
  }

  void _ensureSuccess(dynamic json) {
    final api = ApiResponse.fromJson(json, null);
    if (!api.success) throw Exception(api.error ?? 'Request failed');
  }
}
