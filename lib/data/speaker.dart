import 'package:flutter_tts/flutter_tts.dart';

enum SpeechSpeed { slow, normal, fast }

/// Read-aloud for Junior screens. Every Junior text block has a button that
/// calls [say].
abstract class Speaker {
  /// Set from the Settings screen.
  SpeechSpeed speed = SpeechSpeed.normal;

  Future<void> say(String text, {bool slow = true});
  Future<void> stop();
}

class TtsSpeaker extends Speaker {
  final _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.setLanguage('en-IN');
    } catch (_) {
      // Fall back to the device default voice.
    }
  }

  @override
  Future<void> say(String text, {bool slow = true}) async {
    await _init();
    await _tts.stop();
    final shift = switch (speed) {
      SpeechSpeed.slow => -0.12,
      SpeechSpeed.normal => 0.0,
      SpeechSpeed.fast => 0.12,
    };
    await _tts.setSpeechRate((slow ? 0.4 : 0.5) + shift);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}

class SilentSpeaker extends Speaker {
  final spoken = <String>[];

  @override
  Future<void> say(String text, {bool slow = true}) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}
