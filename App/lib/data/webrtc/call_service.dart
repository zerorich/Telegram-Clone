import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

enum CallMedia { audio, video }

enum CallPhase {
  idle,
  outgoing,
  incoming,
  connecting,
  active,
  ended,
}

class CallSession {
  final String callId;
  final String fromUserId;
  final String toUserId;
  final CallMedia media;
  final CallPhase phase;
  final String? endReason;
  final RTCPeerConnection? peerConnection;
  final MediaStream? localStream;
  final MediaStream? remoteStream;

  const CallSession({
    required this.callId,
    required this.fromUserId,
    required this.toUserId,
    required this.media,
    this.phase = CallPhase.idle,
    this.endReason,
    this.peerConnection,
    this.localStream,
    this.remoteStream,
  });

  CallSession copyWith({
    CallPhase? phase,
    String? endReason,
    RTCPeerConnection? peerConnection,
    MediaStream? localStream,
    MediaStream? remoteStream,
    bool clearRemote = false,
  }) {
    return CallSession(
      callId: callId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      media: media,
      phase: phase ?? this.phase,
      endReason: endReason ?? this.endReason,
      peerConnection: peerConnection ?? this.peerConnection,
      localStream: localStream ?? this.localStream,
      remoteStream: clearRemote ? null : (remoteStream ?? this.remoteStream),
    );
  }
}

typedef CallSignallingSender = void Function(
  String type,
  Map<String, dynamic> payload,
);

class CallService {
  CallService({required this.onSignallingSend}) {
    _sessionController.add(null);
  }

  final CallSignallingSender onSignallingSend;
  final _uuid = const Uuid();

  CallSession? _session;
  String? _myUserId;
  CallSession? get session => _session;

  final _sessionController = StreamController<CallSession?>.broadcast();
  Stream<CallSession?> get sessionStream => _sessionController.stream;

  Future<void> startOutgoing({
    required String myUserId,
    required String peerUserId,
    required CallMedia media,
  }) async {
    await _cleanup();
    _myUserId = myUserId;
    final callId = _uuid.v4();
    _session = CallSession(
      callId: callId,
      fromUserId: myUserId,
      toUserId: peerUserId,
      media: media,
      phase: CallPhase.outgoing,
    );
    _emit();

    final pc = await _createPeerConnection();
    final local = await _getUserMedia(video: media == CallMedia.video);
    for (final track in local.getTracks()) {
      await pc.addTrack(track, local);
    }
    _session = _session!.copyWith(
      peerConnection: pc,
      localStream: local,
      phase: CallPhase.connecting,
    );
    _wirePeerConnection(pc);
    _emit();

    final offer = await pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': media == CallMedia.video,
    });
    await pc.setLocalDescription(offer);
    onSignallingSend('call.offer', {
      'callId': callId,
      'fromUserId': myUserId,
      'toUserId': peerUserId,
      'sdp': offer.sdp,
      'media': media == CallMedia.video ? 'video' : 'audio',
    });
  }

  Future<void> acceptIncoming({required String myUserId}) async {
    _myUserId = myUserId;
    final s = _session;
    if (s == null || s.phase != CallPhase.incoming) return;
    final pc = await _createPeerConnection();
    final local = await _getUserMedia(video: s.media == CallMedia.video);
    for (final track in local.getTracks()) {
      await pc.addTrack(track, local);
    }
    _session = s.copyWith(
      peerConnection: pc,
      localStream: local,
      phase: CallPhase.connecting,
    );
    _wirePeerConnection(pc);
    _emit();

    final pendingSdp = _pendingRemoteSdp;
    if (pendingSdp != null) {
      await pc.setRemoteDescription(
        RTCSessionDescription(pendingSdp, 'offer'),
      );
      _pendingRemoteSdp = null;
    }
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    onSignallingSend('call.answer', {
      'callId': s.callId,
      'fromUserId': myUserId,
      'toUserId': s.fromUserId,
      'sdp': answer.sdp,
    });
  }

  String? _pendingRemoteSdp;

  Future<void> handleOffer(Map<String, dynamic> data) async {
    final callId = data['callId']?.toString() ?? '';
    final fromUserId = data['fromUserId']?.toString() ?? '';
    final toUserId = data['toUserId']?.toString() ?? '';
    final sdp = data['sdp']?.toString();
    final mediaStr = data['media']?.toString() ?? 'audio';
    if (callId.isEmpty || sdp == null) return;

    if (_session != null && _session!.phase != CallPhase.idle) {
      endCall(reason: 'busy');
      return;
    }

    _session = CallSession(
      callId: callId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      media: mediaStr == 'video' ? CallMedia.video : CallMedia.audio,
      phase: CallPhase.incoming,
    );
    _pendingRemoteSdp = sdp;
    _emit();
  }

  Future<void> handleAnswer(Map<String, dynamic> data) async {
    final s = _session;
    final sdp = data['sdp']?.toString();
    if (s == null || sdp == null) return;
    final pc = s.peerConnection;
    if (pc == null) return;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    _session = s.copyWith(phase: CallPhase.active);
    _emit();
  }

  Future<void> handleIce(Map<String, dynamic> data) async {
    final s = _session;
    final candidate = data['candidate'];
    if (s?.peerConnection == null || candidate == null) return;
    final map = candidate is Map
        ? Map<String, dynamic>.from(candidate)
        : <String, dynamic>{};
    await s!.peerConnection!.addCandidate(
      RTCIceCandidate(
        map['candidate']?.toString(),
        map['sdpMid']?.toString(),
        map['sdpMLineIndex'] is int
            ? map['sdpMLineIndex'] as int
            : int.tryParse('${map['sdpMLineIndex']}'),
      ),
    );
  }

  Future<void> endCall({String reason = 'hangup', bool notify = true}) async {
    final s = _session;
    final me = _myUserId;
    if (s == null) return;
    if (notify && me != null) {
      final peer = s.fromUserId == me ? s.toUserId : s.fromUserId;
      onSignallingSend('call.end', {
        'callId': s.callId,
        'fromUserId': me,
        'toUserId': peer,
        'reason': reason,
      });
    }
    _session = s.copyWith(phase: CallPhase.ended, endReason: reason);
    _emit();
    await _cleanup();
    _session = null;
    _emit();
  }

  void handleRemoteEnd(Map<String, dynamic> data) {
    final reason = data['reason']?.toString() ?? 'remote_hangup';
    final s = _session;
    if (s == null) return;
    _session = s.copyWith(phase: CallPhase.ended, endReason: reason);
    _emit();
    unawaited(_cleanup().then((_) {
      _session = null;
      _emit();
    }),);
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });
    pc.onIceCandidate = (c) {
      final s = _session;
      final me = _myUserId;
      if (s == null || me == null) return;
      final peer = s.fromUserId == me ? s.toUserId : s.fromUserId;
      onSignallingSend('call.ice', {
        'callId': s.callId,
        'fromUserId': me,
        'toUserId': peer,
        'candidate': {
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        },
      });
    };
    return pc;
  }

  void _wirePeerConnection(RTCPeerConnection pc) {
    pc.onTrack = (event) {
      final s = _session;
      if (s == null || event.streams.isEmpty) return;
      _session = s.copyWith(
        remoteStream: event.streams.first,
        phase: CallPhase.active,
      );
      _emit();
    };
    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        endCall(reason: 'connection_failed');
      }
    };
  }

  Future<MediaStream> _getUserMedia({required bool video}) async {
    return navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video,
    });
  }

  Future<void> _cleanup() async {
    final s = _session;
    if (s == null) return;
    for (final t in s.localStream?.getTracks() ?? const []) {
      await t.stop();
    }
    for (final t in s.remoteStream?.getTracks() ?? const []) {
      await t.stop();
    }
    await s.localStream?.dispose();
    await s.remoteStream?.dispose();
    await s.peerConnection?.close();
  }

  void _emit() => _sessionController.add(_session);

  void dispose() {
    unawaited(_cleanup());
    _sessionController.close();
  }
}
