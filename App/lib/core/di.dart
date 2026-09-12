import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/data/api/auth_api.dart';
import 'package:telegramclone/data/api/chats_api.dart';
import 'package:telegramclone/data/api/devices_api.dart';
import 'package:telegramclone/data/api/dio_client.dart';
import 'package:telegramclone/data/api/messages_api.dart';
import 'package:telegramclone/data/api/users_api.dart';
import 'package:telegramclone/data/repositories/auth_repository.dart';
import 'package:telegramclone/data/repositories/chat_repository.dart';
import 'package:telegramclone/data/repositories/message_repository.dart';
import 'package:telegramclone/data/websocket/ws_client.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

// Bare Dio used only for token refresh / unauthenticated auth calls, to avoid
// a circular dependency with the interceptor-equipped [dioProvider].
final _bareAuthDioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ),);
});

final authApiProvider =
    Provider<AuthApi>((ref) => AuthApi(ref.watch(_bareAuthDioProvider)));

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(
    ref.watch(secureStorageProvider),
    ref.watch(authApiProvider),
  );
});

final dioProvider = Provider<Dio>((ref) => ref.watch(dioClientProvider).dio);

final usersApiProvider = Provider<UsersApi>((ref) => UsersApi(ref.watch(dioProvider)));
final devicesApiProvider =
    Provider<DevicesApi>((ref) => DevicesApi(ref.watch(dioProvider)));
final chatsApiProvider = Provider<ChatsApi>((ref) => ChatsApi(ref.watch(dioProvider)));
final messagesApiProvider =
    Provider<MessagesApi>((ref) => MessagesApi(ref.watch(dioProvider)));

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    AuthApi(ref.watch(dioProvider)),
    ref.watch(secureStorageProvider),
  );
});

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => ChatRepository(ref.watch(chatsApiProvider)));

final messageRepositoryProvider = Provider<MessageRepository>(
    (ref) => MessageRepository(ref.watch(messagesApiProvider)),);

final wsClientProvider = Provider<WsClient>((ref) {
  final client = WsClient();
  ref.onDispose(() => client.disconnect());
  return client;
});
