import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/di.dart';
import 'package:telegramclone/data/api/auth_api.dart';
import 'package:telegramclone/data/models/user.dart';
import 'package:telegramclone/data/repositories/auth_repository.dart';
import 'package:telegramclone/providers/ws_provider.dart';
import 'package:telegramclone/services/fcm_service.dart';

class AuthDraft {
  String email = '';
  bool isNewUser = false;
  String? registrationToken;
}

final authDraftProvider = StateProvider<AuthDraft>((_) => AuthDraft());

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;

  const AuthState({required this.status, this.user});
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _auth;
  final Ref _ref;

  AuthNotifier(this._auth, this._ref)
      : super(const AuthState(status: AuthStatus.unknown));

  Future<void> checkAuth() async {
    final token = await _auth.getAccessToken();
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    AppConstants.cachedAccessToken = token;
    try {
      final user = await _ref.read(usersApiProvider).getMe();
      state = AuthState(status: AuthStatus.authenticated, user: user);
      await _ref.read(wsServiceProvider).connect();
      await _registerPushToken();
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> sendCode(String email) => _auth.sendCode(email);

  Future<VerifyCodeResult> verifyCode(String email, String code) async {
    final result = await _auth.verifyCode(email, code);
    if (!result.isNewUser && result.user != null && result.tokens != null) {
      await _auth.saveSession(result.user!, result.tokens!);
      AppConstants.cachedAccessToken = result.tokens!.accessToken;
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
      await _ref.read(wsServiceProvider).connect();
      await _registerPushToken();
    }
    return result;
  }

  Future<void> completeProfile({
    required String email,
    required String name,
    required String registrationToken,
    String? surname,
    String? phone,
  }) async {
    final result = await _auth.completeProfile(
      email: email,
      name: name,
      registrationToken: registrationToken,
      surname: surname,
      phone: phone,
    );
    AppConstants.cachedAccessToken = result.tokens.accessToken;
    state = AuthState(status: AuthStatus.authenticated, user: result.user);
    await _ref.read(wsServiceProvider).connect();
    await _registerPushToken();
  }

  Future<void> _registerPushToken() async {
    await FcmService.instance.init(
      devicesApi: _ref.read(devicesApiProvider),
    );
    await FcmService.instance.registerTokenAfterLogin();
  }

  Future<void> logout() => _signOut(callServer: true);

  /// Triggered when refresh fails permanently — clears local state without
  /// calling the server (the tokens are already invalid).
  Future<void> forceLogout() => _signOut(callServer: false);

  Future<void> _signOut({required bool callServer}) async {
    try {
      await _ref.read(wsServiceProvider).disconnect();
      await _clearLocalCaches();
      if (callServer) {
        await _auth.clearSession();
      } else {
        await _auth.clearLocalSession();
      }
    } finally {
      await FcmService.instance.clearRegistration();
      AppConstants.cachedAccessToken = null;
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _clearLocalCaches() async {
    final chatRepo = _ref.read(chatRepositoryProvider);
    final msgRepo = _ref.read(messageRepositoryProvider);
    try {
      final ids = await chatRepo.cachedChatIds();
      await msgRepo.clearAllCaches(ids);
    } catch (_) {}
    try {
      await chatRepo.clearAllCaches();
    } catch (_) {}
    try {
      _ref.read(onlineUsersProvider.notifier).clear();
    } catch (_) {}
  }

  void setUser(UserModel user) {
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(ref.watch(authRepositoryProvider), ref);
  // Forward 401-on-refresh-failure into a clean app-wide logout.
  ref
      .read(dioClientProvider)
      .setAuthFailureCallback(() => notifier.forceLogout());
  return notifier;
});
