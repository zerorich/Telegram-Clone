import 'package:equatable/equatable.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/json_map.dart';

class UserModel extends Equatable {
  final String id;
  final String phone;
  final String email;
  final String name;
  final String? surname;
  final String? username;
  final String? avatarUrl;
  final bool isVerified;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.phone,
    required this.email,
    required this.name,
    this.surname,
    this.username,
    this.avatarUrl,
    this.isVerified = false,
    this.createdAt,
  });

  String get displayName {
    if (name.isNotEmpty) {
      return surname != null && surname!.isNotEmpty ? '$name $surname' : name;
    }
    return username ?? phone;
  }

  String get fullAvatarUrl => AppConstants.mediaUrl(avatarUrl);

  factory UserModel.fromJson(dynamic json) {
    final map = asJsonMap(json);
    return UserModel(
      id: map['id'].toString(),
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      surname: map['surname'] as String?,
      username: map['username'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      isVerified: map['is_verified'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'surname': surname,
        'username': username,
      };

  UserModel copyWith({
    String? name,
    String? surname,
    String? username,
    String? avatarUrl,
  }) {
    return UserModel(
      id: id,
      phone: phone,
      email: email,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, phone, email, name];
}
