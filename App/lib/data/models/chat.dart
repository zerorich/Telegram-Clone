import 'package:equatable/equatable.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/json_map.dart';
import 'package:telegramclone/data/models/chat_member.dart';
import 'package:telegramclone/data/models/message.dart';

enum ChatType { direct, group }

ChatType chatTypeFromString(String? v) =>
    v == 'group' ? ChatType.group : ChatType.direct;

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
  });

  String get fullAvatarUrl => AppConstants.mediaUrl(avatarUrl);

  String displayTitle(String currentUserId, {Map<String, String>? peerNames}) {
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
    );
  }

  ChatModel copyWith({
    MessageModel? lastMessage,
    int? unreadCount,
    String? name,
    String? avatarUrl,
    List<ChatMemberModel>? members,
  }) {
    return ChatModel(
      id: id,
      type: type,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdBy: createdBy,
      createdAt: createdAt,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      members: members ?? this.members,
    );
  }

  @override
  List<Object?> get props => [id, lastMessage?.id];
}

class ChatDetail {
  final ChatModel chat;
  final List<ChatMemberModel> members;

  ChatDetail({required this.chat, required this.members});
}
