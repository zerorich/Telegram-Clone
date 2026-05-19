import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telegramclone/core/di.dart';
import 'package:telegramclone/data/models/message.dart';
import 'package:telegramclone/data/repositories/auth_repository.dart';
import 'package:telegramclone/data/websocket/ws_client.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/chats_provider.dart';
import 'package:telegramclone/providers/messages_provider.dart';

class WsService {
  final WsClient _client;
  final AuthRepository _auth;
  final Ref _ref;

  WsService(this._client, this._auth, this._ref) {
    _client.addListener(_handleEvent);
  }

  Future<void> connect() async {
    final token = await _auth.getAccessToken();
    if (token != null) await _client.connect(token);
  }

  Future<void> disconnect() => _client.disconnect();

  void _handleEvent(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'message.new':
        _ref.read(chatsListProvider.notifier).onNewMessage(data);
        final chatId = data['chat_id']?.toString();
        if (chatId != null && _ref.exists(messagesProvider(chatId))) {
          _ref.read(messagesProvider(chatId).notifier).onNewMessage(data);
        }
        break;
      case 'message.updated':
      case 'message.deleted':
        final chatId = data['chat_id']?.toString();
        if (chatId == null) break;
        if (_ref.exists(messagesProvider(chatId))) {
          if (type == 'message.updated') {
            _ref.read(messagesProvider(chatId).notifier).onMessageUpdated(data);
          } else {
            _ref.read(messagesProvider(chatId).notifier).onMessageDeleted(data);
          }
        } else {
          _ref.read(chatsListProvider.notifier).onMessageChanged(
                MessageModel.fromJson(data),
              );
        }
        break;
      case 'message.read':
        final chatId = data['chat_id']?.toString();
        if (chatId == null) break;
        final readerId = data['user_id']?.toString();
        final me = _ref.read(authProvider).user?.id;
        if (readerId != null && me != null && readerId != me) {
          _ref.read(chatsListProvider.notifier).onMessageRead(
                chatId: chatId,
                readerId: readerId,
                currentUserId: me,
              );
        }
        if (_ref.exists(messagesProvider(chatId))) {
          _ref.read(messagesProvider(chatId).notifier).onMessageRead(data);
        }
        break;
      case 'typing':
        final chatId = data['chat_id'] as String?;
        if (chatId != null) {
          _ref.read(typingProvider(chatId).notifier).setTyping(
                data['user_id'] as String? ?? '',
                data['is_typing'] as bool? ?? false,
              );
        }
        break;
      case 'user.online':
        _ref.read(onlineUsersProvider.notifier).updateOnline(
              data['user_id'] as String? ?? '',
              data['is_online'] as bool? ?? false,
            );
        break;
    }
  }

  void sendTyping(String chatId, bool typing) =>
      _client.sendTyping(chatId, typing);

  void sendRead(String chatId, String messageId) =>
      _client.sendRead(chatId, messageId);
}

final wsServiceProvider = Provider<WsService>((ref) {
  return WsService(
    ref.watch(wsClientProvider),
    ref.watch(authRepositoryProvider),
    ref,
  );
});

final onlineUsersProvider =
    StateNotifierProvider<OnlineUsersNotifier, Map<String, bool>>((ref) {
  return OnlineUsersNotifier();
});

class OnlineUsersNotifier extends StateNotifier<Map<String, bool>> {
  OnlineUsersNotifier() : super({});

  void updateOnline(String userId, bool isOnline) {
    state = {...state, userId: isOnline};
  }
}

final typingProvider =
    StateNotifierProvider.family<TypingNotifier, String?, String>((ref, chatId) {
  return TypingNotifier();
});

class TypingNotifier extends StateNotifier<String?> {
  TypingNotifier() : super(null);

  void setTyping(String userId, bool isTyping) {
    state = isTyping ? userId : null;
  }
}
