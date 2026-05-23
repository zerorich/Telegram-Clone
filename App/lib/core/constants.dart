// Build-time overrides:
//   flutter run --dart-define=API_BASE_URL=https://example.com \
//               --dart-define=WS_URL=wss://example.com/ws
// Defaults target Android emulator (10.0.2.2 = host loopback).
class AppConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // defaultValue: 'http://10.0.2.2:8080',
    defaultValue: 'https://western-canal-cheap-glance.trycloudflare.com',
  );
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    // defaultValue: 'ws://10.0.2.2:8080/ws',
    defaultValue: 'wss://western-canal-cheap-glance.trycloudflare.com/ws',
  );

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';

  static const int messagesPageSize = 50;
  static const int typingHideSeconds = 3;

  /// In-memory copy of the current access token. Populated by [AuthNotifier]
  /// on login / refresh / restore and cleared on logout. Used by [mediaUrl]
  /// to append `?t=<jwt>` to relative `/uploads/*` paths, since the server
  /// now JWT-gates that route and `<img>` / `<video>` tags can't set
  /// `Authorization` headers.
  static String? cachedAccessToken;

  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final token = cachedAccessToken;
    if (token == null || token.isEmpty) return '$baseUrl$path';
    final sep = path.contains('?') ? '&' : '?';
    return '$baseUrl$path${sep}t=${Uri.encodeComponent(token)}';
  }
}
