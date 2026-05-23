import 'package:dio/dio.dart';

/// Extracts a short, human-readable error message from any exception type.
///
/// Priority order:
/// 1. Server JSON body  `{"error": "..."}` (from our API convention)
/// 2. Connection / timeout errors → localised strings
/// 3. Raw exception message with `Exception:` prefix stripped
String friendlyError(Object e) {
  if (e is DioException) {
    // The DioClient interceptor stores the clean server message in `error`
    // as a plain String when it finds it in the response body.
    if (e.error is String) {
      final msg = e.error as String;
      if (msg.isNotEmpty) return msg;
    }

    // Fallback: parse the response body ourselves (should not happen if
    // DioClient interceptor is set up correctly, but defensive).
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['error'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    }

    // Network-level errors
    switch (e.type) {
      case DioExceptionType.connectionError:
        return 'Нет подключения к серверу';
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Превышено время ожидания';
      case DioExceptionType.cancel:
        return 'Запрос отменён';
      default:
        break;
    }

    // HTTP status fallback
    final code = e.response?.statusCode;
    if (code != null) {
      return switch (code) {
        400 => 'Неверные данные',
        401 => 'Ошибка авторизации',
        403 => 'Нет доступа',
        404 => 'Не найдено',
        422 => 'Ошибка валидации',
        429 => 'Слишком много запросов',
        500 || 502 || 503 => 'Ошибка сервера',
        _ => 'Ошибка $code',
      };
    }

    return 'Ошибка сети';
  }

  // Plain Exception — strip the Dart prefix
  final s = e.toString();
  if (s.startsWith('Exception: ')) return s.substring(11);
  return s;
}
