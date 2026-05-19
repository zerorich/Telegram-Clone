import 'package:audioplayers/audioplayers.dart';

/// Call once at app startup so voice messages use the media speaker on Android.
Future<void> initAppAudio() async {
  try {
    await AudioPlayer.global.setAudioContext(
    AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.speech,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.defaultToSpeaker,
          AVAudioSessionOptions.mixWithOthers,
        },
      ),
    ),
    );
  } catch (_) {
    // Some devices fail audio context setup; playback may still work.
  }
}
