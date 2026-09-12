import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/data/webrtc/call_service.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/call_provider.dart';

class CallOverlay extends ConsumerStatefulWidget {
  const CallOverlay({super.key});

  @override
  ConsumerState<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends ConsumerState<CallOverlay> {
  final _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(callSessionProvider);
    if (session == null || session.phase == CallPhase.idle) {
      return const SizedBox.shrink();
    }

    if (session.remoteStream != null &&
        _remoteRenderer.srcObject != session.remoteStream) {
      _remoteRenderer.srcObject = session.remoteStream;
    }

    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Text(
              _phaseLabel(session.phase),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (session.media == CallMedia.video && session.remoteStream != null)
              Expanded(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (session.phase == CallPhase.incoming) ...[
                  Semantics(
                    label: 'Принять звонок',
                    button: true,
                    child: FloatingActionButton(
                      heroTag: 'accept_call',
                      backgroundColor: Colors.green,
                      onPressed: () {
                        final myId = ref.read(authProvider).user?.id;
                        if (myId == null) return;
                        ref.read(callServiceProvider).acceptIncoming(myUserId: myId);
                      },
                      child: const Icon(Icons.call),
                    ),
                  ),
                  Semantics(
                    label: 'Отклонить звонок',
                    button: true,
                    child: FloatingActionButton(
                      heroTag: 'reject_call',
                      backgroundColor: Colors.red,
                      onPressed: () =>
                          ref.read(callServiceProvider).endCall(reason: 'declined'),
                      child: const Icon(Icons.call_end),
                    ),
                  ),
                ] else ...[
                  Semantics(
                    label: 'Завершить звонок',
                    button: true,
                    child: FloatingActionButton(
                      heroTag: 'end_call',
                      backgroundColor: Colors.red,
                      onPressed: () => ref.read(callServiceProvider).endCall(),
                      child: const Icon(Icons.call_end),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
            if (session.phase == CallPhase.outgoing ||
                session.phase == CallPhase.connecting)
              TextButton(
                onPressed: () =>
                    ref.read(callServiceProvider).endCall(reason: 'cancelled'),
                child: Text(
                  'Отмена',
                  style: TextStyle(color: context.subtitleColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _phaseLabel(CallPhase phase) {
    switch (phase) {
      case CallPhase.outgoing:
        return 'Вызов...';
      case CallPhase.incoming:
        return 'Входящий звонок';
      case CallPhase.connecting:
        return 'Соединение...';
      case CallPhase.active:
        return 'Разговор';
      case CallPhase.ended:
        return 'Звонок завершён';
      case CallPhase.idle:
        return '';
    }
  }
}
