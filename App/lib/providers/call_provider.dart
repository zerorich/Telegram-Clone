import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telegramclone/core/di.dart';
import 'package:telegramclone/data/webrtc/call_service.dart';
import 'package:telegramclone/providers/auth_provider.dart';

final callServiceProvider = Provider<CallService>((ref) {
  final ws = ref.watch(wsClientProvider);
  final service = CallService(
    onSignallingSend: (type, payload) {
      ws.send(type, payload);
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

class CallSessionNotifier extends StateNotifier<CallSession?> {
  CallSessionNotifier(this._service) : super(_service.session) {
    _sub = _service.sessionStream.listen((s) => state = s);
  }

  final CallService _service;
  late final StreamSubscription<CallSession?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final callSessionProvider =
    StateNotifierProvider<CallSessionNotifier, CallSession?>((ref) {
  return CallSessionNotifier(ref.watch(callServiceProvider));
});

/// Starts a voice or video call to [peerUserId] in a direct chat.
Future<void> startCall(
  WidgetRef ref, {
  required String peerUserId,
  required CallMedia media,
}) async {
  final myId = ref.read(authProvider).user?.id;
  if (myId == null) return;
  await ref.read(callServiceProvider).startOutgoing(
        myUserId: myId,
        peerUserId: peerUserId,
        media: media,
      );
}
