import 'package:equatable/equatable.dart';
import 'package:telegramclone/core/json_map.dart';
import 'package:telegramclone/data/models/user.dart';

enum MemberRole { member, admin, owner }

MemberRole memberRoleFromString(String? v) {
  switch (v) {
    case 'admin':
      return MemberRole.admin;
    case 'owner':
      return MemberRole.owner;
    default:
      return MemberRole.member;
  }
}

class ChatMemberModel extends Equatable {
  final String chatId;
  final String userId;
  final DateTime joinedAt;
  final MemberRole role;
  final UserModel? user;

  const ChatMemberModel({
    required this.chatId,
    required this.userId,
    required this.joinedAt,
    required this.role,
    this.user,
  });

  factory ChatMemberModel.fromJson(dynamic json) {
    final map = asJsonMap(json);
    return ChatMemberModel(
      chatId: map['chat_id'].toString(),
      userId: map['user_id'].toString(),
      joinedAt: DateTime.parse(map['joined_at'] as String),
      role: memberRoleFromString(map['role'] as String?),
      user: map['user'] != null ? UserModel.fromJson(map['user']) : null,
    );
  }

  @override
  List<Object?> get props => [chatId, userId];
}
