import 'package:flutter/foundation.dart';

// Build-time overrides (required for release):
//   flutter run --dart-define=API_BASE_URL=https://example.com \
//               --dart-define=WS_URL=wss://example.com/ws
// Debug builds default to Android emulator host (10.0.2.2 = host loopback).
class AppConstants {
  static const String _apiFromEnv = String.fromEnvironment('API_BASE_URL');
  static const String _wsFromEnv = String.fromEnvironment('WS_URL');

  static const String _debugBaseUrl = 'http://10.0.2.2:8080';
  static const String _debugWsUrl = 'ws://10.0.2.2:8080/ws';

  static String get baseUrl {
    if (_apiFromEnv.isNotEmpty) return _apiFromEnv;
    assert(
      !kReleaseMode,
      'Pass --dart-define=API_BASE_URL=... for release builds',
    );
    if (kReleaseMode) {
      throw StateError(
        'API_BASE_URL is required in release. '
        'Pass --dart-define=API_BASE_URL=...',
      );
    }
    return _debugBaseUrl;
  }

  static String get wsUrl {
    if (_wsFromEnv.isNotEmpty) return _wsFromEnv;
    assert(
      !kReleaseMode,
      'Pass --dart-define=WS_URL=... for release builds',
    );
    if (kReleaseMode) {
      throw StateError(
        'WS_URL is required in release. Pass --dart-define=WS_URL=...',
      );
    }
    return _debugWsUrl;
  }

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
