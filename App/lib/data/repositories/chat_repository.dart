import 'package:hive_flutter/hive_flutter.dart';
import 'package:telegramclone/data/api/chats_api.dart';
import 'package:telegramclone/data/models/chat.dart';
import 'package:telegramclone/data/models/chat_member.dart';
import 'package:telegramclone/data/models/message.dart';
import 'package:telegramclone/data/models/user.dart';

class ChatRepository {
  final ChatsApi _api;
  static const _boxName = 'chats_cache';
  static const _savedKey = 'saved';

  ChatRepository(this._api);

  Future<Box> _box() async => Hive.openBox(_boxName);

  /// Cached chats for instant UI (may be stale).
  Future<List<ChatModel>> readCachedChats() async {
    final box = await _box();
    final cached = box.get('list');
    if (cached is! List) return [];
    return cached.map((e) => ChatModel.fromJson(e)).toList();
  }

  Future<ChatModel?> readCachedSaved() async {
    final box = await _box();
    final cached = box.get(_savedKey);
    if (cached == null) return null;
    try {
      return ChatModel.fromJson(cached);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheSaved(ChatModel? chat) async {
    final box = await _box();
    if (chat == null) {
      await box.delete(_savedKey);
    } else {
      await box.put(_savedKey, _chatToCache(chat));
    }
  }

  /// Always loads from API and refreshes cache.
  Future<List<ChatModel>> fetchChatsFromNetwork() async {
    final chats = await _api.listChats();
    await _cacheChats(chats);
    return chats;
  }

  Future<ChatModel?> fetchSavedFromNetwork() async {
    try {
      final saved = await _api.getSaved();
      await cacheSaved(saved);
      return saved;
    } catch (_) {
      // Saved-chat endpoint not available on old servers — degrade gracefully.
      return null;
    }
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
        'type': chatTypeToString(c.type),
        'name': c.name,
        'avatar_url': c.avatarUrl,
        'created_by': c.createdBy,
        'created_at': c.createdAt.toIso8601String(),
        if (c.lastMessage != null) 'last_message': _messageToCache(c.lastMessage!),
        'unread_count': c.unreadCount,
        'members': c.members.map(_memberToCache).toList(),
        if (c.mutedUntil != null) 'muted_until': c.mutedUntil!.toIso8601String(),
      };

  Map<String, dynamic> _messageToCache(dynamic m) {
    // Defensive — duplicated from message_repository to keep last_message cache
    // self-contained and prevent breakage if MessageModel grows fields.
    return {
      'id': m.id,
      'chat_id': m.chatId,
      'sender_id': m.senderId,
      'type': messageTypeToString(m.type as MessageType),
      'content': m.content,
      'media_url': m.mediaUrl,
      'duration_sec': m.durationSec,
      'reply_to_id': m.replyToId,
      'is_edited': m.isEdited,
      'is_deleted': m.isDeleted,
      'is_read': m.isRead,
      'is_pinned': m.isPinned,
      if (m.pinnedAt != null) 'pinned_at': m.pinnedAt.toIso8601String(),
      'forwarded_from_user_id': m.forwardedFromUserId,
      'forwarded_from_chat_id': m.forwardedFromChatId,
      'created_at': m.createdAt.toIso8601String(),
    };
  }

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
          {String? name, String? avatarPath,}) =>
      _api.updateGroup(chatId, name: name, avatarPath: avatarPath);

  Future<void> addMembers(String chatId, List<String> memberIds) =>
      _api.addMembers(chatId, memberIds);

  Future<void> removeMember(String chatId, String userId) =>
      _api.removeMember(chatId, userId);

  Future<void> leaveGroup(String chatId) => _api.leaveGroup(chatId);

  Future<void> deleteChat(String chatId) => _api.deleteChat(chatId);

  Future<void> mute(String chatId, {DateTime? until}) =>
      _api.mute(chatId, until: until);

  Future<void> unmute(String chatId) => _api.unmute(chatId);

  Future<void> updateCachedChat(ChatModel chat) async {
    if (chat.type == ChatType.saved) {
      await cacheSaved(chat);
      return;
    }
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

  Future<void> removeCachedChat(String chatId) async {
    final chats = await readCachedChats();
    chats.removeWhere((c) => c.id == chatId);
    await _cacheChats(chats);
    final saved = await readCachedSaved();
    if (saved?.id == chatId) {
      await cacheSaved(null);
    }
  }

  /// Returns IDs of currently cached chats so callers can clear per-chat boxes.
  Future<List<String>> cachedChatIds() async {
    final chats = await readCachedChats();
    final saved = await readCachedSaved();
    final ids = chats.map((c) => c.id).toList();
    if (saved != null) ids.add(saved.id);
    return ids;
  }

  /// Wipes the chat list cache. Used on logout / forced sign-out.
  Future<void> clearAllCaches() async {
    if (Hive.isBoxOpen(_boxName)) {
      await Hive.box(_boxName).clear();
    } else {
      final box = await _box();
      await box.clear();
    }
  }
}
