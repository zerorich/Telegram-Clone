import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telegramclone/core/di.dart';
import 'package:telegramclone/data/models/user.dart';
import 'package:telegramclone/data/repositories/auth_repository.dart';
import 'package:telegramclone/providers/ws_provider.dart';

class AuthDraft {
  String email = '';
  bool isNewUser = false;
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
    final has = await _auth.hasToken();
    if (!has) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _ref.read(usersApiProvider).getMe();
      state = AuthState(status: AuthStatus.authenticated, user: user);
      _ref.read(wsServiceProvider).connect();
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> sendCode(String email) => _auth.sendCode(email);

  Future<bool> verifyCode(String email, String code) async {
    final result = await _auth.verifyCode(email, code);
    if (result.isNewUser) {
      return true;
    }
    if (result.user != null && result.tokens != null) {
      await _auth.saveSession(result.user!, result.tokens!);
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
      await _ref.read(wsServiceProvider).connect();
    }
    return false;
  }

  Future<void> completeProfile({
    required String email,
    required String name,
    String? surname,
    String? phone,
  }) async {
    final result = await _auth.completeProfile(
      email: email,
      name: name,
      surname: surname,
      phone: phone,
    );
    state = AuthState(status: AuthStatus.authenticated, user: result.user);
    await _ref.read(wsServiceProvider).connect();
  }

  Future<void> logout() async {
    await _ref.read(wsServiceProvider).disconnect();
    await _auth.clearSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void setUser(UserModel user) {
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});
