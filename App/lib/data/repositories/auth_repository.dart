import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/data/api/auth_api.dart';
import 'package:telegramclone/data/models/token_pair.dart';
import 'package:telegramclone/data/models/user.dart';

class AuthRepository {
  final AuthApi _api;
  final FlutterSecureStorage _storage;

  AuthRepository(this._api, this._storage);

  Future<bool> hasToken() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.accessTokenKey);

  Future<void> saveSession(UserModel user, TokenPair tokens) async {
    await _storage.write(
        key: AppConstants.accessTokenKey, value: tokens.accessToken,);
    await _storage.write(
        key: AppConstants.refreshTokenKey, value: tokens.refreshToken,);
    await _storage.write(key: AppConstants.userIdKey, value: user.id);
  }

  Future<void> clearSession() async {
    final refresh = await _storage.read(key: AppConstants.refreshTokenKey);
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } catch (_) {}
    }
    await _storage.deleteAll();
  }

  /// Wipes locally stored tokens without notifying the server. Used when
  /// refresh has already failed (the server doesn't trust our tokens anyway).
  Future<void> clearLocalSession() async {
    await _storage.deleteAll();
  }

  Future<void> sendCode(String email) => _api.sendCode(email);

  Future<VerifyCodeResult> verifyCode(String email, String code) =>
      _api.verifyCode(email, code);

  Future<({UserModel user, TokenPair tokens})> completeProfile({
    required String email,
    required String name,
    required String registrationToken,
    String? surname,
    String? phone,
  }) async {
    final result = await _api.completeProfile(
      email: email,
      name: name,
      registrationToken: registrationToken,
      surname: surname,
      phone: phone,
    );
    await saveSession(result.user, result.tokens);
    return result;
  }

  Future<String?> getUserId() => _storage.read(key: AppConstants.userIdKey);
}
