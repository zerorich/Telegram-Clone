import 'package:dio/dio.dart';

class DevicesApi {
  DevicesApi(this._dio);

  final Dio _dio;

  Future<void> registerPushToken({
    required String token,
    String platform = 'android',
  }) async {
    await _dio.post('/api/devices/push-token', data: {
      'token': token,
      'platform': platform,
    },);
  }
}
