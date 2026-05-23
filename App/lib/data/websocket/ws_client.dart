import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/json_map.dart';

typedef WsEventHandler = void Function(String type, Map<String, dynamic> data);
typedef WsTokenProvider = Future<String?> Function();

class WsClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  int _backoffSeconds = 1;
  bool _disposed = false;
  WsTokenProvider? _tokenProvider;
  final _handlers = <WsEventHandler>[];

  WsClient({WsTokenProvider? tokenProvider}) : _tokenProvider = tokenProvider;

  void setTokenProvider(WsTokenProvider provider) {
    _tokenProvider = provider;
  }

  void addListener(WsEventHandler handler) => _handlers.add(handler);
  void removeListener(WsEventHandler handler) => _handlers.remove(handler);

  Future<void> connect() async {
    _disposed = false;
    await _connectInternal();
  }

  Future<void> _connectInternal() async {
    if (_disposed) return;
    final provider = _tokenProvider;
    if (provider == null) return;
    final token = await provider();
    if (token == null || token.isEmpty) return;
    if (_disposed) return;
    try {
      // Legacy ?token=<jwt> query-string auth. The subprotocol-based path
      // (Sec-WebSocket-Protocol: bearer.<token>) is rejected by Dart's
      // web_socket_channel when the Fiber/fasthttp upgrade response doesn't
      // echo back the chosen subprotocol.
      final uri = Uri.parse(
        '${AppConstants.wsUrl}?token=${Uri.encodeComponent(token)}',
      );
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
      // Snapshot to avoid ConcurrentModificationError if a handler add/removes
      // listeners while we're iterating.
      for (final h in List.of(_handlers)) {
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
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _backoffSeconds = 1;
  }
}
