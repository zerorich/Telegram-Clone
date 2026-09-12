import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:telegramclone/data/api/devices_api.dart';
import 'package:telegramclone/main.dart';

/// Placeholder [google-services.json] uses project_id `telegram-clone-dev`.
/// Replace `App/android/app/google-services.json` with your real Firebase
/// Android config before shipping push to production devices.
class FcmService {
  FcmService._();
  static final instance = FcmService._();

  bool _available = false;
  bool get isAvailable => _available;

  FirebaseMessaging? _messaging;
  DevicesApi? _devicesApi;
  String? _lastRegisteredToken;

  Future<void> init({DevicesApi? devicesApi}) async {
    _devicesApi = devicesApi;
    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
      await _messaging!.setAutoInitEnabled(true);

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onOpenedFromNotification);

      _available = true;
    } catch (e, st) {
      _available = false;
      debugPrint('FCM unavailable (placeholder Firebase config?): $e\n$st');
    }
  }

  Future<void> registerTokenAfterLogin() async {
    if (!_available || _devicesApi == null) return;
    try {
      final token = await _messaging!.getToken();
      if (token == null || token.isEmpty) return;
      if (token == _lastRegisteredToken) return;
      await _devicesApi!.registerPushToken(token: token);
      _lastRegisteredToken = token;
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  Future<void> clearRegistration() async {
    _lastRegisteredToken = null;
    if (!_available) return;
    try {
      await _messaging?.deleteToken();
    } catch (_) {}
  }

  void _onForegroundMessage(RemoteMessage message) {
    unawaited(_showRemoteNotification(message));
  }

  void _onOpenedFromNotification(RemoteMessage message) {
    // Deep link routing can be added when server payload includes chat_id.
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _showRemoteNotification(message);
}

Future<void> _showRemoteNotification(RemoteMessage message) async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notificationsPlugin.initialize(
    const InitializationSettings(android: android),
  );

  final data = message.data;
  final title = message.notification?.title ??
      data['title']?.toString() ??
      'Новое сообщение';
  final body = message.notification?.body ??
      data['body']?.toString() ??
      data['content']?.toString() ??
      '';

  final chatId = data['chat_id']?.toString() ?? message.messageId ?? 'msg';

  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'messages',
      'Сообщения',
      channelDescription: 'Уведомления о новых сообщениях',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  await notificationsPlugin.show(
    chatId.hashCode,
    title,
    body.isEmpty ? 'Сообщение' : body,
    details,
    payload: jsonEncode(data),
  );
}
