import 'package:equatable/equatable.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/json_map.dart';
import 'package:telegramclone/data/models/user.dart';

enum MessageType { text, image, video, voice, file }

MessageType messageTypeFromString(String? v) {
  switch (v) {
    case 'image':
      return MessageType.image;
    case 'video':
      return MessageType.video;
    case 'voice':
      return MessageType.voice;
    case 'file':
      return MessageType.file;
    default:
      return MessageType.text;
  }
}

// Manual stringifier — `EnumName.name` requires Dart SDK >= 2.15 and blows up
// at runtime on older Dart VMs that some shipped builds were AOT-compiled
// against, so we avoid `.name` on enums entirely.
String messageTypeToString(MessageType t) {
  switch (t) {
    case MessageType.text:
      return 'text';
    case MessageType.image:
      return 'image';
    case MessageType.video:
      return 'video';
    case MessageType.voice:
      return 'voice';
    case MessageType.file:
      return 'file';
  }
}

class MessageModel extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final MessageType type;
  final String? content;
  final String? mediaUrl;
  final int? durationSec;
  final String? replyToId;
  final bool isEdited;
  final bool isDeleted;
  final DateTime createdAt;
  final bool isRead;
  final bool isPinned;
  final DateTime? pinnedAt;
  final String? forwardedFromUserId;
  final String? forwardedFromChatId;
  final UserModel? forwardedFromUser;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    this.content,
    this.mediaUrl,
    this.durationSec,
    this.replyToId,
    this.isEdited = false,
    this.isDeleted = false,
    required this.createdAt,
    this.isRead = false,
    this.isPinned = false,
    this.pinnedAt,
    this.forwardedFromUserId,
    this.forwardedFromChatId,
    this.forwardedFromUser,
  });

  String get fullMediaUrl => AppConstants.mediaUrl(mediaUrl);

  bool get isForwarded => forwardedFromUserId != null;

  static int? _parseDurationSec(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory MessageModel.fromJson(dynamic json) {
    final map = asJsonMap(json);
    return MessageModel(
      id: map['id'].toString(),
      chatId: map['chat_id'].toString(),
      senderId: map['sender_id'].toString(),
      type: messageTypeFromString(map['type'] as String?),
      content: map['content'] as String?,
      mediaUrl: map['media_url'] as String?,
      durationSec: _parseDurationSec(map['duration_sec']),
      replyToId: map['reply_to_id']?.toString(),
      isEdited: map['is_edited'] as bool? ?? false,
      isDeleted: map['is_deleted'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      isRead: map['is_read'] as bool? ?? false,
      isPinned: map['is_pinned'] as bool? ?? false,
      pinnedAt: map['pinned_at'] != null
          ? DateTime.tryParse(map['pinned_at'].toString())
          : null,
      forwardedFromUserId: map['forwarded_from_user_id']?.toString(),
      forwardedFromChatId: map['forwarded_from_chat_id']?.toString(),
      forwardedFromUser: map['forwarded_from_user'] != null
          ? UserModel.fromJson(map['forwarded_from_user'])
          : null,
    );
  }

  MessageModel copyWith({
    bool? isRead,
    bool? isEdited,
    bool? isDeleted,
    String? content,
    bool? isPinned,
    DateTime? pinnedAt,
    String? forwardedFromUserId,
    String? forwardedFromChatId,
    UserModel? forwardedFromUser,
    bool clearPinnedAt = false,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      type: type,
      content: content ?? this.content,
      mediaUrl: mediaUrl,
      durationSec: durationSec,
      replyToId: replyToId,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: clearPinnedAt ? null : (pinnedAt ?? this.pinnedAt),
      forwardedFromUserId: forwardedFromUserId ?? this.forwardedFromUserId,
      forwardedFromChatId: forwardedFromChatId ?? this.forwardedFromChatId,
      forwardedFromUser: forwardedFromUser ?? this.forwardedFromUser,
    );
  }

  @override
  List<Object?> get props => [id, chatId, createdAt, isRead, isPinned, isDeleted];
}
