import 'package:dio/dio.dart';
import 'package:telegramclone/data/api/api_helpers.dart';
import 'package:telegramclone/data/models/api_response.dart';
import 'package:telegramclone/data/models/user.dart';

class UsersApi {
  final Dio _dio;

  UsersApi(this._dio);

  Future<UserModel> getMe() async {
    final res = await _dio.get('/api/users/me');
    return UserModel.fromJson(_parseData(res.data));
  }

  Future<UserModel> updateMe({
    required String name,
    String? surname,
    String? username,
  }) async {
    final res = await _dio.patch('/api/users/me', data: {
      'name': name,
      'surname': surname,
      'username': username,
    });
    return UserModel.fromJson(_parseData(res.data));
  }

  Future<UserModel> uploadAvatar(String filePath) async {
    final form = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post('/api/users/me/avatar', data: form);
    return UserModel.fromJson(_parseData(res.data));
  }

  Future<UserModel> getUser(String userId) async {
    final res = await _dio.get('/api/users/$userId');
    return UserModel.fromJson(_parseData(res.data));
  }

  Future<List<UserModel>> search(String query) async {
    final res = await _dio.get('/api/users/search', queryParameters: {'q': query});
    return parseDataList(_parseData(res.data), UserModel.fromJson);
  }

  dynamic _parseData(dynamic json) {
    final api = ApiResponse.fromJson(json, null);
    if (!api.success) throw Exception(api.error ?? 'Request failed');
    return api.data;
  }
}
