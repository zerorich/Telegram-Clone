import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/data/api/auth_api.dart';

class DioClient {
  late final Dio dio;
  final FlutterSecureStorage _storage;
  final AuthApi _authApi;
  bool _isRefreshing = false;

  DioClient(this._storage, this._authApi) {
    dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Let Dio set multipart boundary; global application/json breaks media upload.
        if (options.data is FormData) {
          options.headers.remove('Content-Type');
        }
        final token = await _storage.read(key: AppConstants.accessTokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final path = error.requestOptions.path;
        final isAuth = path.startsWith('/api/auth/');
        if (error.response?.statusCode == 401 && !isAuth) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            final token = await _storage.read(key: AppConstants.accessTokenKey);
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _tryRefresh() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final refresh = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refresh == null) return false;
      final tokens = await _authApi.refresh(refresh);
      await _storage.write(
          key: AppConstants.accessTokenKey, value: tokens.accessToken);
      await _storage.write(
          key: AppConstants.refreshTokenKey, value: tokens.refreshToken);
      return true;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }
}
