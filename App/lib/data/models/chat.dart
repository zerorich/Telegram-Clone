import 'package:equatable/equatable.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/json_map.dart';
import 'package:telegramclone/data/models/chat_member.dart';
import 'package:telegramclone/data/models/message.dart';

enum ChatType { direct, group, saved }

ChatType chatTypeFromString(String? v) {
  switch (v) {
    case 'group':
      return ChatType.group;
    case 'saved':
      return ChatType.saved;
    default:
      return ChatType.direct;
  }
}

String chatTypeToString(ChatType t) {
  switch (t) {
    case ChatType.group:
      return 'group';
    case ChatType.saved:
      return 'saved';
    case ChatType.direct:
      return 'direct';
  }
}

class ChatModel extends Equatable {
  final String id;
  final ChatType type;
  final String? name;
  final String? avatarUrl;
  final String? createdBy;
  final DateTime createdAt;
  final MessageModel? lastMessage;
  final int unreadCount;
  final List<ChatMemberModel> members;
  final DateTime? mutedUntil;

  const ChatModel({
    required this.id,
    required this.type,
    this.name,
    this.avatarUrl,
    this.createdBy,
    required this.createdAt,
    this.lastMessage,
    this.unreadCount = 0,
    this.members = const [],
    this.mutedUntil,
  });

  String get fullAvatarUrl => AppConstants.mediaUrl(avatarUrl);

  bool get isSaved => type == ChatType.saved;

  bool get isMuted {
    final until = mutedUntil;
    if (until == null) return false;
    // `until == epoch` (or any far-past sentinel) treated as not muted; null
    // means permanent mute in the API contract but we also accept very-far
    // future as permanent. Otherwise we only consider it muted while in future.
    return until.isAfter(DateTime.now());
  }

  /// True when the chat is muted forever (no expiration).
  bool get isMutedForever {
    final until = mutedUntil;
    if (until == null) return false;
    // Treat anything past year 9000 as effectively permanent.
    return until.year >= 9000;
  }

  String displayTitle(String currentUserId, {Map<String, String>? peerNames}) {
    if (type == ChatType.saved) return 'Избранное';
    if (type == ChatType.group && name != null && name!.isNotEmpty) {
      return name!;
    }
    if (type == ChatType.direct) {
      final peer = peerMember(currentUserId);
      if (peer?.user != null) {
        return peer!.user!.displayName;
      }
      if (peerNames != null) {
        for (final entry in peerNames.entries) {
          if (entry.key != currentUserId) return entry.value;
        }
      }
    }
    return name ?? 'Chat';
  }

  ChatMemberModel? peerMember(String currentUserId) {
    for (final m in members) {
      if (m.userId != currentUserId) return m;
    }
    return null;
  }

  String? peerAvatarUrl(String currentUserId) {
    if (type == ChatType.saved) return null;
    if (type == ChatType.group) {
      return avatarUrl;
    }
    return peerMember(currentUserId)?.user?.avatarUrl ?? avatarUrl;
  }

  factory ChatModel.fromJson(dynamic json) {
    final map = asJsonMap(json);
    return ChatModel(
      id: map['id'].toString(),
      type: chatTypeFromString(map['type'] as String?),
      name: map['name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      createdBy: map['created_by']?.toString(),
      createdAt: DateTime.parse(map['created_at'] as String),
      lastMessage: map['last_message'] != null
          ? MessageModel.fromJson(map['last_message'])
          : null,
      unreadCount: map['unread_count'] as int? ?? 0,
      members: asJsonMapList(map['members'])
          .map(ChatMemberModel.fromJson)
          .toList(),
      mutedUntil: map['muted_until'] != null
          ? DateTime.tryParse(map['muted_until'].toString())
          : null,
    );
  }

  ChatModel copyWith({
    MessageModel? lastMessage,
    int? unreadCount,
    String? name,
    String? avatarUrl,
    List<ChatMemberModel>? members,
    DateTime? mutedUntil,
    bool clearLastMessage = false,
    bool clearMutedUntil = false,
  }) {
    return ChatModel(
      id: id,
      type: type,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdBy: createdBy,
      createdAt: createdAt,
      lastMessage:
          clearLastMessage ? null : (lastMessage ?? this.lastMessage),
      unreadCount: unreadCount ?? this.unreadCount,
      members: members ?? this.members,
      mutedUntil: clearMutedUntil ? null : (mutedUntil ?? this.mutedUntil),
    );
  }

  @override
  List<Object?> get props => [id, lastMessage?.id, mutedUntil];
}

class ChatDetail {
  final ChatModel chat;
  final List<ChatMemberModel> members;

  ChatDetail({required this.chat, required this.members});
}
