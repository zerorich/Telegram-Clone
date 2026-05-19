import 'package:telegramclone/core/json_map.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResponse({required this.success, this.data, this.error});

  factory ApiResponse.fromJson(
    dynamic json,
    T Function(dynamic)? parser,
  ) {
    final map = asJsonMap(json);
    return ApiResponse(
      success: map['success'] as bool? ?? false,
      data: parser != null && map['data'] != null
          ? parser(map['data'])
          : map['data'] as T?,
      error: map['error'] as String?,
    );
  }
}
