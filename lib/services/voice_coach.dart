import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks exercise feedback without repeating rapidly changing camera results.
class VoiceCoach {
  VoiceCoach() : _tts = FlutterTts() {
    _initialization = _initialize();
  }

  final FlutterTts _tts;
  late final Future<void> _initialization;
  String? _lastKey;
  DateTime? _lastSpokenAt;
  bool _disposed = false;

  Future<void> _initialize() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.46);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(false);
    } catch (error) {
      debugPrint('Unable to initialize voice coach: $error');
    }
  }

  Future<void> speak(
    String feedback, {
    bool force = false,
    Duration minimumGap = const Duration(milliseconds: 2500),
    Duration repeatAfter = const Duration(seconds: 7),
  }) async {
    if (_disposed) return;

    final message = _speechFriendly(feedback);
    if (message.isEmpty) return;

    final now = DateTime.now();
    final elapsed = _lastSpokenAt == null
        ? null
        : now.difference(_lastSpokenAt!);
    final key = message.toLowerCase();

    if (!force && elapsed != null) {
      if (elapsed < minimumGap || (key == _lastKey && elapsed < repeatAfter)) {
        return;
      }
    }

    _lastKey = key;
    _lastSpokenAt = now;
    await _initialization;
    if (_disposed) return;

    try {
      if (force) await _tts.stop();
      await _tts.speak(message);
    } catch (error) {
      debugPrint('Unable to speak exercise feedback: $error');
    }
  }

  String _speechFriendly(String feedback) {
    var message = feedback.trim();

    // Angle values and hold-frame counters change on nearly every camera frame.
    // Speak the useful instruction while leaving the detailed value on screen.
    if (message.startsWith('Increase ') || message.startsWith('Reduce ')) {
      final separator = message.indexOf(':');
      if (separator > 0) message = '${message.substring(0, separator)}.';
    }
    if (message.startsWith('Good position. Hold steady')) {
      message = 'Good position. Hold steady.';
    }

    return message;
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _tts.stop();
    } catch (_) {
      // The speech engine may already have been released by the platform.
    }
  }
}
