import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps TTS ("speak total") and speech-to-text ("voice input").
/// Every call is guarded so a missing engine never breaks billing.
class VoiceService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  bool _ttsReady = false;
  bool _sttReady = false;
  bool _listening = false;

  bool get ttsAvailable => _ttsReady;

  bool get sttAvailable => _sttReady;

  bool get isListening => _listening;

  void _setListening(bool value) {
    if (_listening == value) return;
    _listening = value;
    notifyListeners();
  }

  Future<void> init() async {
    try {
      _ttsReady = await _tts.isLanguageAvailable('en-IN');
      if (!_ttsReady) {
        _ttsReady = await _tts.isLanguageAvailable('en-US');
      }
      if (_ttsReady) {
        await _tts.setLanguage('en-IN');
        await _tts.setSpeechRate(0.55);
      }
    } catch (_) {
      _ttsReady = false;
    }
    try {
      _sttReady = await _stt.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _setListening(false);
          }
        },
        onError: (_) => _setListening(false),
      );
    } catch (_) {
      _sttReady = false;
    }
    notifyListeners();
  }

  /// Speaks "Total 3,400 rupees" style text.
  Future<void> speak(String text) async {
    if (!_ttsReady) return;
    try {
      await _tts.speak(text);
    } catch (_) {
      // Never crash billing because of speech.
    }
  }

  Future<void> stopSpeaking() async {
    if (!_ttsReady) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Starts listening. [onDigits] receives the digits spoken by the user.
  Future<void> listen({required ValueChanged<String> onDigits}) async {
    if (!_sttReady || _listening) return;
    try {
      _setListening(true);
      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          final digits = result.recognizedWords
              .split('')
              .where((c) => RegExp(r'[0-9]').hasMatch(c))
              .join();
          if (digits.isNotEmpty) {
            onDigits(digits);
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 8),
          localeId: 'en_IN',
          cancelOnError: true,
        ),
      );
    } catch (_) {
      _setListening(false);
    }
  }

  Future<void> stopListening() async {
    if (!_listening) return;
    try {
      await _stt.stop();
    } catch (_) {}
    _setListening(false);
  }

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }
}