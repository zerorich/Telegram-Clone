import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:telegramclone/app.dart';
import 'package:telegramclone/core/audio_config.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final notificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notificationsPlugin.initialize(
    const InitializationSettings(android: android),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initializeDateFormatting('ru');
  runApp(const ProviderScope(child: TelegramCloneApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    initAppAudio();
    _initNotifications();
  });
}
