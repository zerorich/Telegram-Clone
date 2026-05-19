import 'package:hive_flutter/hive_flutter.dart';
import 'package:telegramclone/data/api/chats_api.dart';
import 'package:telegramclone/data/models/chat.dart';
import 'package:telegramclone/data/models/chat_member.dart';
import 'package:telegramclone/data/models/user.dart';

class ChatRepository {
  final ChatsApi _api;
  static const _boxName = 'chats_cache';

  ChatRepository(this._api);

  Future<Box> _box() async => Hive.openBox(_boxName);

  /// Cached chats for instant UI (may be stale).
  Future<List<ChatModel>> readCachedChats() async {
    final box = await _box();
    final cached = box.get('list');
    if (cached is! List) return [];
    return cached.map((e) => ChatModel.fromJson(e)).toList();
  }

  /// Always loads from API and refreshes cache.
  Future<List<ChatModel>> fetchChatsFromNetwork() async {
    final chats = await _api.listChats();
    await _cacheChats(chats);
    return chats;
  }

  Future<List<ChatModel>> getChats({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await readCachedChats();
      if (cached.isNotEmpty) return cached;
    }
    return fetchChatsFromNetwork();
  }

  Future<void> _cacheChats(List<ChatModel> chats) async {
    final box = await _box();
    await box.put('list', chats.map(_chatToCache).toList());
  }

  Map<String, dynamic> _chatToCache(ChatModel c) => {
        'id': c.id,
        'type': c.type == ChatType.group ? 'group' : 'direct',
        'name': c.name,
        'avatar_url': c.avatarUrl,
        'created_by': c.createdBy,
        'created_at': c.createdAt.toIso8601String(),
        if (c.lastMessage != null)
          'last_message': {
            'id': c.lastMessage!.id,
            'chat_id': c.lastMessage!.chatId,
            'sender_id': c.lastMessage!.senderId,
            'type': c.lastMessage!.type.name,
            'content': c.lastMessage!.content,
            'media_url': c.lastMessage!.mediaUrl,
            'duration_sec': c.lastMessage!.durationSec,
            'reply_to_id': c.lastMessage!.replyToId,
            'is_edited': c.lastMessage!.isEdited,
            'is_deleted': c.lastMessage!.isDeleted,
            'is_read': c.lastMessage!.isRead,
            'created_at': c.lastMessage!.createdAt.toIso8601String(),
          },
        'unread_count': c.unreadCount,
        'members': c.members.map(_memberToCache).toList(),
      };

  Map<String, dynamic> _memberToCache(ChatMemberModel m) => {
        'chat_id': m.chatId,
        'user_id': m.userId,
        'joined_at': m.joinedAt.toIso8601String(),
        'role': _roleToString(m.role),
        if (m.user != null) 'user': _userToCache(m.user!),
      };

  String _roleToString(MemberRole role) {
    switch (role) {
      case MemberRole.admin:
        return 'admin';
      case MemberRole.owner:
        return 'owner';
      case MemberRole.member:
        return 'member';
    }
  }

  Map<String, dynamic> _userToCache(UserModel u) => {
        'id': u.id,
        'phone': u.phone,
        'email': u.email,
        'name': u.name,
        'surname': u.surname,
        'username': u.username,
        'avatar_url': u.avatarUrl,
        'is_verified': u.isVerified,
        if (u.createdAt != null) 'created_at': u.createdAt!.toIso8601String(),
      };

  Future<ChatModel> createDirect(String userId) => _api.createDirect(userId);

  Future<ChatModel> createGroup({
    required String name,
    required List<String> memberIds,
    String? avatarPath,
  }) =>
      _api.createGroup(
        name: name,
        memberIds: memberIds,
        avatarPath: avatarPath,
      );

  Future<ChatDetail> getChat(String chatId) => _api.getChat(chatId);

  Future<ChatModel> updateGroup(String chatId,
          {String? name, String? avatarPath}) =>
      _api.updateGroup(chatId, name: name, avatarPath: avatarPath);

  Future<void> addMembers(String chatId, List<String> memberIds) =>
      _api.addMembers(chatId, memberIds);

  Future<void> removeMember(String chatId, String userId) =>
      _api.removeMember(chatId, userId);

  Future<void> leaveGroup(String chatId) => _api.leaveGroup(chatId);

  Future<void> updateCachedChat(ChatModel chat) async {
    final chats = await readCachedChats();
    final idx = chats.indexWhere((c) => c.id == chat.id);
    if (idx >= 0) {
      chats[idx] = chat;
    } else {
      chats.insert(0, chat);
    }
    chats.sort((a, b) {
      final at = a.lastMessage?.createdAt ?? a.createdAt;
      final bt = b.lastMessage?.createdAt ?? b.createdAt;
      return bt.compareTo(at);
    });
    await _cacheChats(chats);
  }
}
