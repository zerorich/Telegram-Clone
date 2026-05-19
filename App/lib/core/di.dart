import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:telegramclone/data/api/auth_api.dart';
import 'package:telegramclone/data/api/chats_api.dart';
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

final authApiProvider = Provider<AuthApi>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://10.0.2.2:8080',
    headers: {'Content-Type': 'application/json'},
  ));
  return AuthApi(dio);
});

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(
    ref.watch(secureStorageProvider),
    ref.watch(authApiProvider),
  );
});

final dioProvider = Provider<Dio>((ref) => ref.watch(dioClientProvider).dio);

final usersApiProvider = Provider<UsersApi>((ref) => UsersApi(ref.watch(dioProvider)));
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
    (ref) => MessageRepository(ref.watch(messagesApiProvider)));

final wsClientProvider = Provider<WsClient>((ref) {
  final client = WsClient();
  ref.onDispose(() => client.disconnect());
  return client;
});
