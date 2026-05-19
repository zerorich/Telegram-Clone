import 'package:telegramclone/core/json_map.dart';

class TokenPair {
  final String accessToken;
  final String refreshToken;

  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
  });

  factory TokenPair.fromJson(dynamic json) {
    final map = asJsonMap(json);
    return TokenPair(
      accessToken: map['access_token'] as String,
      refreshToken: map['refresh_token'] as String,
    );
  }
}
