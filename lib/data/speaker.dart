import 'package:flutter_tts/flutter_tts.dart';

/// Read-aloud for Junior screens. Every Junior text block has a button that
/// calls [say].
abstract class Speaker {
  Future<void> say(String text, {bool slow = true});
  Future<void> stop();
}

class TtsSpeaker implements Speaker {
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
    await _tts.setSpeechRate(slow ? 0.4 : 0.5);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}

class SilentSpeaker implements Speaker {
  final spoken = <String>[];

  @override
  Future<void> say(String text, {bool slow = true}) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}
