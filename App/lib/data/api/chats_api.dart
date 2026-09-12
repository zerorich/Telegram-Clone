import 'package:dio/dio.dart';
import 'package:telegramclone/core/json_map.dart';
import 'package:telegramclone/data/api/api_helpers.dart';
import 'package:telegramclone/data/models/api_response.dart';
import 'package:telegramclone/data/models/chat.dart';
import 'package:telegramclone/data/models/chat_member.dart';

class ChatsApi {
  final Dio _dio;

  ChatsApi(this._dio);

  Future<List<ChatModel>> listChats() async {
    final res = await _dio.get('/api/chats');
    return parseDataList(_parseData(res.data), ChatModel.fromJson);
  }

  /// Returns the caller's Saved Messages chat. Server auto-creates if missing.
  /// May 404 on older servers — caller should treat that as null.
  Future<ChatModel> getSaved() async {
    final res = await _dio.get('/api/chats/saved');
    return ChatModel.fromJson(_parseData(res.data));
  }

  Future<ChatModel> createDirect(String userId) async {
    final res = await _dio.post('/api/chats/direct', data: {'user_id': userId});
    return ChatModel.fromJson(_parseData(res.data));
  }

  Future<ChatModel> createGroup({
    required String name,
    required List<String> memberIds,
    String? avatarPath,
  }) async {
    if (avatarPath != null) {
      final form = FormData();
      form.fields.add(MapEntry('name', name));
      form.fields.add(MapEntry(
        'member_ids',
        '[${memberIds.map((id) => '"$id"').join(',')}]',
      ),);
      form.files.add(MapEntry(
        'avatar',
        await MultipartFile.fromFile(avatarPath),
      ),);
      final res = await _dio.post('/api/chats/group', data: form);
      return ChatModel.fromJson(_parseData(res.data));
    }
    final res = await _dio.post('/api/chats/group', data: {
      'name': name,
      'member_ids': memberIds,
    },);
    return ChatModel.fromJson(_parseData(res.data));
  }

  Future<ChatDetail> getChat(String chatId) async {
    final res = await _dio.get('/api/chats/$chatId');
    final data = asJsonMap(_parseData(res.data));
    final chat = ChatModel.fromJson(data['chat']);
    final members = parseDataList(
      data['members'],
      ChatMemberModel.fromJson,
    );
    return ChatDetail(chat: chat.copyWith(members: members), members: members);
  }

  Future<ChatModel> updateGroup(String chatId, {String? name, String? avatarPath}) async {
    if (avatarPath != null) {
      final form = FormData.fromMap({
        if (name != null) 'name': name,
        'avatar': await MultipartFile.fromFile(avatarPath),
      });
      final res = await _dio.patch('/api/chats/$chatId', data: form);
      return ChatModel.fromJson(_parseData(res.data));
    }
    final res = await _dio.patch('/api/chats/$chatId', data: {
      if (name != null) 'name': name,
    },);
    return ChatModel.fromJson(_parseData(res.data));
  }

  Future<void> addMembers(String chatId, List<String> memberIds) async {
    final res = await _dio.post('/api/chats/$chatId/members', data: {
      'member_ids': memberIds,
    },);
    _ensureSuccess(res.data);
  }

  Future<void> removeMember(String chatId, String userId) async {
    final res = await _dio.delete('/api/chats/$chatId/members/$userId');
    _ensureSuccess(res.data);
  }

  Future<void> leaveGroup(String chatId) async {
    final res = await _dio.delete('/api/chats/$chatId/leave');
    _ensureSuccess(res.data);
  }

  /// Deletes the chat. Server enforces direct/group/saved rules.
  Future<void> deleteChat(String chatId) async {
    final res = await _dio.delete('/api/chats/$chatId');
    _ensureSuccess(res.data);
  }

  /// Mutes the chat. `until == null` means permanent mute.
  Future<void> mute(String chatId, {DateTime? until}) async {
    final res = await _dio.post(
      '/api/chats/$chatId/mute',
      data: {'until': until?.toUtc().toIso8601String()},
    );
    _ensureSuccess(res.data);
  }

  Future<void> unmute(String chatId) async {
    final res = await _dio.delete('/api/chats/$chatId/mute');
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
