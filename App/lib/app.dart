import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telegramclone/core/router.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/providers/theme_provider.dart';
import 'package:telegramclone/providers/ws_provider.dart';
import 'package:telegramclone/ui/widgets/call_overlay.dart';

class TelegramCloneApp extends ConsumerStatefulWidget {
  const TelegramCloneApp({super.key});

  @override
  ConsumerState<TelegramCloneApp> createState() => _TelegramCloneAppState();
}

class _TelegramCloneAppState extends ConsumerState<TelegramCloneApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appInBackgroundProvider.notifier).state =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final isDark = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Telegram Clone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const Positioned.fill(child: CallOverlay()),
          ],
        );
      },
    );
  }
}
