import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/data/api/auth_api.dart';

typedef AuthFailureCallback = Future<void> Function();

class DioClient {
  late final Dio dio;
  final FlutterSecureStorage _storage;
  final AuthApi _authApi;
  Future<bool>? _refreshFuture;
  AuthFailureCallback? _onAuthFailure;

  DioClient(this._storage, this._authApi, {AuthFailureCallback? onAuthFailure})
      : _onAuthFailure = onAuthFailure {
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
        // ── Extract clean server error message from 4xx / 5xx bodies ──────────
        // Our API always returns {"success": false, "error": "..."} for errors.
        // We store the clean string in `error.error` so friendlyError() can
        // pick it up without the caller needing to know about DioException.
        final resp = error.response;
        final statusCode = resp?.statusCode ?? 0;
        if (resp != null && statusCode >= 400 && statusCode != 401) {
          String? serverMsg;
          try {
            final data = resp.data;
            if (data is Map) serverMsg = data['error'] as String?;
          } catch (_) {}
          if (serverMsg != null && serverMsg.isNotEmpty) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: resp,
                type: DioExceptionType.badResponse,
                error: serverMsg, // ← clean message, not a Dart Exception object
              ),
            );
          }
        }
        // ── Standard 401 → token refresh logic ───────────────────────────────
        final path = error.requestOptions.path;
        final isAuth = path.startsWith('/api/auth/');
        if (error.response?.statusCode != 401 || isAuth) {
          return handler.next(error);
        }

        final refreshed = await _tryRefresh();
        if (!refreshed) {
          // Refresh failed permanently — force a clean logout once and bail.
          final cb = _onAuthFailure;
          if (cb != null) {
            unawaited(cb());
          }
          return handler.next(error);
        }

        // TODO: streaming/FormData replay is unsafe — the underlying stream has
        // already been consumed by the failed attempt, so we can't safely
        // re-upload it. Surface the original error and let the caller retry.
        if (error.requestOptions.data is FormData) {
          return handler.next(error);
        }

        final token = await _storage.read(key: AppConstants.accessTokenKey);
        error.requestOptions.headers['Authorization'] = 'Bearer $token';
        try {
          final response = await dio.fetch(error.requestOptions);
          return handler.resolve(response);
        } catch (_) {
          return handler.next(error);
        }
      },
    ));
  }

  void setAuthFailureCallback(AuthFailureCallback callback) {
    _onAuthFailure = callback;
  }

  Future<bool> _tryRefresh() {
    final inflight = _refreshFuture;
    if (inflight != null) return inflight;
    final fresh = _performRefresh();
    _refreshFuture = fresh;
    fresh.whenComplete(() {
      if (identical(_refreshFuture, fresh)) _refreshFuture = null;
    });
    return fresh;
  }

  Future<bool> _performRefresh() async {
    try {
      final refresh = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refresh == null) return false;
      final tokens = await _authApi.refresh(refresh);
      await _storage.write(
          key: AppConstants.accessTokenKey, value: tokens.accessToken);
      await _storage.write(
          key: AppConstants.refreshTokenKey, value: tokens.refreshToken);
      AppConstants.cachedAccessToken = tokens.accessToken;
      return true;
    } catch (_) {
      return false;
    }
  }
}
