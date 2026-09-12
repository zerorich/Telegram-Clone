import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:telegramclone/main.dart';

const _settingsBox = 'app_settings';
const _notificationsEnabledKey = 'notifications_enabled';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  bool _initialized = false;
  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notificationsPlugin.initialize(
      const InitializationSettings(android: android),
    );
    final box = await Hive.openBox(_settingsBox);
    _enabled = box.get(_notificationsEnabledKey, defaultValue: true) as bool;
    _initialized = true;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final box = await Hive.openBox(_settingsBox);
    await box.put(_notificationsEnabledKey, value);
  }

  Future<void> showMessageNotification({
    required String title,
    required String body,
    required String chatId,
  }) async {
    if (!_enabled) return;
    if (!_initialized) await init();

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
      body,
      details,
    );
  }
}
