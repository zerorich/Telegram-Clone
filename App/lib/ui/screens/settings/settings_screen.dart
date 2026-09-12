import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/theme_provider.dart';
import 'package:telegramclone/services/notification_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    await NotificationService.instance.init();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = NotificationService.instance.enabled;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Настройки'),
        backgroundColor: context.appBarBg,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Тёмная тема'),
            subtitle: const Text('Как в Telegram'),
            value: isDark,
            activeTrackColor: AppColors.teal,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Уведомления'),
            subtitle: Text(
              _loading
                  ? 'Загрузка...'
                  : (_notificationsEnabled
                      ? 'Включены для новых сообщений'
                      : 'Выключены'),
            ),
            value: _notificationsEnabled,
            activeTrackColor: AppColors.teal,
            onChanged: _loading
                ? null
                : (v) async {
                    await NotificationService.instance.setEnabled(v);
                    if (!mounted) return;
                    setState(() => _notificationsEnabled = v);
                  },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline, color: AppColors.teal),
            title: Text('О приложении'),
            subtitle: Text('Telegram Clone v1.0.0'),
          ),
          const Divider(),
          Semantics(
            label: 'Выйти из аккаунта',
            button: true,
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Выйти', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/auth/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}
