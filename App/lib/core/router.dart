import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/ui/screens/auth/complete_profile_screen.dart';
import 'package:telegramclone/ui/screens/auth/login_screen.dart';
import 'package:telegramclone/ui/screens/auth/otp_screen.dart';
import 'package:telegramclone/ui/screens/chat/chat_screen.dart';
import 'package:telegramclone/ui/screens/group/group_info_screen.dart';
import 'package:telegramclone/ui/screens/home/home_screen.dart';
import 'package:telegramclone/ui/screens/new_chat/new_chat_screen.dart';
import 'package:telegramclone/ui/screens/new_group/new_group_screen.dart';
import 'package:telegramclone/ui/screens/profile/profile_screen.dart';
import 'package:telegramclone/ui/screens/profile/user_profile_screen.dart';
import 'package:telegramclone/ui/screens/settings/settings_screen.dart';
import 'package:telegramclone/ui/screens/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRefresh(ref);
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      final isAuth = auth.status == AuthStatus.authenticated;
      final isSplash = loc == '/splash';
      final isAuthRoute = loc.startsWith('/auth');

      if (auth.status == AuthStatus.unknown) {
        return isSplash ? null : '/splash';
      }
      if (isAuth && (isAuthRoute || isSplash)) return '/home';
      if (!isAuth && !isAuthRoute && !isSplash) return '/auth/login';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/auth/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (_, __) => const OtpScreen(),
      ),
      GoRoute(
        path: '/auth/complete',
        builder: (_, __) => const CompleteProfileScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: ChatScreen(chatId: state.pathParameters['id']!),
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final offset = Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ));
            return SlideTransition(position: offset, child: child);
          },
        ),
      ),
      GoRoute(path: '/new-chat', builder: (_, __) => const NewChatScreen()),
      GoRoute(path: '/new-group', builder: (_, __) => const NewGroupScreen()),
      GoRoute(
        path: '/group/:id',
        builder: (_, state) =>
            GroupInfoScreen(chatId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(
        path: '/user/:id',
        builder: (_, state) =>
            UserProfileScreen(userId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
