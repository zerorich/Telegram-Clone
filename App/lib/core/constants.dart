class AppConstants {
  // static const String baseUrl = 'http://10.0.2.2:8080';
  static const String baseUrl = 'http://192.168.0.181:8080';
  static const String wsUrl = 'ws://192.168.0.181:8080/ws';
  // static const String wsUrl = 'ws://10.0.2.2:8080/ws';

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';

  static const int messagesPageSize = 50;
  static const int typingHideSeconds = 3;

  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }
}
