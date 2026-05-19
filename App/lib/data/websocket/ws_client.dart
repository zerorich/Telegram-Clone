import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/json_map.dart';

typedef WsEventHandler = void Function(String type, Map<String, dynamic> data);

class WsClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  int _backoffSeconds = 1;
  bool _disposed = false;
  String? _token;
  final _handlers = <WsEventHandler>[];

  void addListener(WsEventHandler handler) => _handlers.add(handler);
  void removeListener(WsEventHandler handler) => _handlers.remove(handler);

  Future<void> connect(String token) async {
    _token = token;
    _disposed = false;
    await _connectInternal();
  }

  Future<void> _connectInternal() async {
    if (_disposed || _token == null) return;
    try {
      final uri = Uri.parse('${AppConstants.wsUrl}?token=$_token');
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: false,
      );
      _backoffSeconds = 1;
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final json = asJsonMap(jsonDecode(raw as String));
      final type = json['type'] as String? ?? '';
      final map = json['data'] != null ? asJsonMap(json['data']) : <String, dynamic>{};
      for (final h in _handlers) {
        h(type, map);
      }
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _subscription?.cancel();
    _channel = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _backoffSeconds), () {
      _backoffSeconds = (_backoffSeconds * 2).clamp(1, 60);
      _connectInternal();
    });
  }

  void send(String type, Map<String, dynamic> payload) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'type': type, ...payload}));
  }

  void sendTyping(String chatId, bool isTyping) {
    send(isTyping ? 'typing.start' : 'typing.stop', {'chat_id': chatId});
  }

  void sendRead(String chatId, String messageId) {
    send('message.read', {'chat_id': chatId, 'message_id': messageId});
  }

  Future<void> disconnect() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }
}
