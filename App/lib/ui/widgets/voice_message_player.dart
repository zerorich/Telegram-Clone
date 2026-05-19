import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String url;
  final int? durationSec;
  final bool isMine;

  const VoiceMessagePlayer({
    super.key,
    required this.url,
    this.durationSec,
    this.isMine = false,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;
  bool _playing = false;
  int? _resolvedDurationSec;

  int get _displaySeconds =>
      widget.durationSec ?? _resolvedDurationSec ?? 0;

  AudioPlayer get _ensurePlayer {
    return _player ??= AudioPlayer(
      playerId: 'voice_${widget.url.hashCode}',
    )..setReleaseMode(ReleaseMode.stop);
  }

  void _attachListeners() {
    _stateSub ??= _ensurePlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
    _completeSub ??= _ensurePlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _completeSub?.cancel();
    final p = _player;
    if (p != null) {
      unawaited(p.stop());
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    final url = widget.url.trim();
    if (url.isEmpty) return;

    final player = _ensurePlayer;
    _attachListeners();

    if (_playing) {
      await player.stop();
      return;
    }

    try {
      await player.stop();
      await player.setVolume(1.0);
      await player.play(UrlSource(url, mimeType: 'audio/mp4'));

      if ((widget.durationSec ?? 0) <= 0) {
        final duration = await player.getDuration();
        if (mounted && duration != null && duration.inMilliseconds > 0) {
          setState(() {
            _resolvedDurationSec =
                (duration.inMilliseconds / 1000).ceil().clamp(1, 3600);
          });
        }
      }
    } catch (e, st) {
      debugPrint('VoiceMessagePlayer: play failed $e\n$st');
      if (mounted) setState(() => _playing = false);
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '—';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isMine ? Colors.black87 : Colors.white;
    final muted = widget.isMine
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.7);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          color: fg,
          onPressed: widget.url.trim().isEmpty ? null : _toggle,
        ),
        Expanded(
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              color: (widget.isMine ? Colors.black : Colors.white)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(Icons.graphic_eq, size: 16, color: muted),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_displaySeconds),
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    );
  }
}
