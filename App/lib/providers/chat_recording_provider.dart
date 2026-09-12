import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:telegramclone/providers/messages_provider.dart';

class ChatRecordingState {
  final bool isRecording;
  final DateTime? startedAt;

  const ChatRecordingState({this.isRecording = false, this.startedAt});
}

class ChatRecordingNotifier extends StateNotifier<ChatRecordingState> {
  ChatRecordingNotifier(this._chatId, this._ref)
      : _recorder = AudioRecorder(),
        super(const ChatRecordingState());

  final String _chatId;
  final Ref _ref;
  final AudioRecorder _recorder;

  Future<String?> start() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return 'Нужен доступ к микрофону';
    final path =
        '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 128000,
        autoGain: true,
      ),
      path: path,
    );
    state = ChatRecordingState(isRecording: true, startedAt: DateTime.now());
    return null;
  }

  Future<String?> stopAndSend({String? replyToId, bool cancel = false}) async {
    final started = state.startedAt;
    state = const ChatRecordingState();
    final path = await _recorder.stop();
    if (cancel || path == null) return null;

    final file = File(path);
    if (!await file.exists() || await file.length() < 512) {
      return 'Запись слишком короткая';
    }

    var durationSec = 1;
    if (started != null) {
      durationSec = DateTime.now().difference(started).inSeconds;
      if (durationSec < 1) durationSec = 1;
    }

    try {
      await _ref.read(messagesProvider(_chatId).notifier).sendMedia(
            type: 'voice',
            path: path,
            durationSec: durationSec,
            replyToId: replyToId,
          );
      return null;
    } catch (_) {
      return 'Не удалось отправить голосовое';
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}

final chatRecordingProvider = StateNotifierProvider.autoDispose
    .family<ChatRecordingNotifier, ChatRecordingState, String>((ref, chatId) {
  return ChatRecordingNotifier(chatId, ref);
});
