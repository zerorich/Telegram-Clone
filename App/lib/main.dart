import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:telegramclone/app.dart';
import 'package:telegramclone/core/audio_config.dart';
import 'package:telegramclone/services/fcm_service.dart';
import 'package:telegramclone/services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final notificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initializeDateFormatting('ru');
  await NotificationService.instance.init();
  // FCM uses placeholder google-services.json until replaced with real Firebase config.
  await FcmService.instance.init();
  runApp(const ProviderScope(child: TelegramCloneApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    initAppAudio();
  });
}
