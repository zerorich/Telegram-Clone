import 'package:dio/dio.dart';
import 'package:telegramclone/core/json_map.dart';
import 'package:telegramclone/data/models/api_response.dart';
import 'package:telegramclone/data/models/token_pair.dart';
import 'package:telegramclone/data/models/user.dart';

class VerifyCodeResult {
  final bool isNewUser;
  final UserModel? user;
  final TokenPair? tokens;

  const VerifyCodeResult({
    required this.isNewUser,
    this.user,
    this.tokens,
  });
}

class AuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  Future<void> sendCode(String email) async {
    final res = await _dio.post('/api/auth/send-code', data: {'email': email});
    _ensureSuccess(res.data);
  }

  Future<VerifyCodeResult> verifyCode(String email, String code) async {
    final res = await _dio.post('/api/auth/verify-code', data: {
      'email': email,
      'code': code,
    });
    final data = _parseData(res.data);
    final isNewUser = data['is_new_user'] as bool? ?? false;
    if (isNewUser) {
      return const VerifyCodeResult(isNewUser: true);
    }
    return VerifyCodeResult(
      isNewUser: false,
      user: UserModel.fromJson(data['user']),
      tokens: TokenPair.fromJson(data['tokens']),
    );
  }

  Future<({UserModel user, TokenPair tokens})> completeProfile({
    required String email,
    required String name,
    String? surname,
    String? phone,
  }) async {
    final res = await _dio.post('/api/auth/complete-profile', data: {
      'email': email,
      'name': name,
      if (surname != null) 'surname': surname,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    final data = _parseData(res.data);
    return (
      user: UserModel.fromJson(data['user']),
      tokens: TokenPair.fromJson(data['tokens']),
    );
  }

  Future<TokenPair> refresh(String refreshToken) async {
    final res = await _dio.post('/api/auth/refresh', data: {
      'refresh_token': refreshToken,
    });
    final data = _parseData(res.data);
    return TokenPair.fromJson(data);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post('/api/auth/logout', data: {
      'refresh_token': refreshToken,
    });
  }

  Map<String, dynamic> _parseData(dynamic json) {
    final api = ApiResponse.fromJson(json, null);
    if (!api.success) {
      throw Exception(api.error ?? 'Request failed');
    }
    return asJsonMap(api.data);
  }

  void _ensureSuccess(dynamic json) {
    final api = ApiResponse.fromJson(json, null);
    if (!api.success) {
      throw Exception(api.error ?? 'Request failed');
    }
  }
}
