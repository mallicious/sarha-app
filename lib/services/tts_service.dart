// lib/services/tts_service.dart - UPDATED WITH DISTANCE ANNOUNCEMENTS

import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io' show Platform;

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  DateTime? _lastAnnouncement;

  TTSService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (Platform.isAndroid) {
        await _configureAndroid();
      } else if (Platform.isIOS) {
        await _configureiOS();
      }

      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.55);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        print('TTS Error: $msg');
      });

      _isInitialized = true;
      print('✅ TTS Service initialized');
    } catch (e) {
      _isInitialized = false;
      print('❌ TTS initialization failed: $e');
    }
  }

  Future<void> _configureAndroid() async {
    try {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (e) {
      print('Android TTS config error: $e');
    }
  }

  Future<void> _configureiOS() async {
    try {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    } catch (e) {
      print('iOS TTS config error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MAIN ANNOUNCEMENT METHOD - WITH DISTANCE
  // ═══════════════════════════════════════════════════════════════
  
  Future<void> announceHazard(String hazardType, {double? distanceMeters, String? roadName}) async {
    if (!_isInitialized) {
      print('⚠️ TTS not initialized');
      return;
    }

    // Prevent announcement spam (min 3 seconds between announcements)
    if (_lastAnnouncement != null && 
        DateTime.now().difference(_lastAnnouncement!) < const Duration(seconds: 3)) {
      return;
    }

    try {
      if (_isSpeaking) {
        await _flutterTts.stop();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      String message = _buildAnnouncementMessage(hazardType, distanceMeters, roadName);
      
      await _flutterTts.speak(message);
      _lastAnnouncement = DateTime.now();
      
      print('🔊 TTS: "$message"');
    } catch (e) {
      print('❌ TTS speak error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD SMART ANNOUNCEMENT MESSAGE
  // ═══════════════════════════════════════════════════════════════
  
  String _buildAnnouncementMessage(String hazardType, double? distance, String? roadName) {
    String message = '';

    // Add urgency based on distance
    if (distance != null) {
      if (distance < 30) {
        message = 'Warning! ';
      } else if (distance < 100) {
        message = 'Caution! ';
      } else {
        message = 'Alert. ';
      }

      // Add hazard type
      message += '$hazardType ';

      // Add distance
      if (distance < 30) {
        message += 'directly ahead';
      } else if (distance < 100) {
        message += 'in ${distance.toStringAsFixed(0)} meters';
      } else {
        message += 'approaching in ${distance.toStringAsFixed(0)} meters';
      }
    } else {
      // No distance - just announce hazard
      message = 'Caution. $hazardType detected';
    }

    // Add road name if available
    if (roadName != null && roadName.isNotEmpty && roadName != 'Unknown location') {
      message += ' on $roadName';
    }

    return message;
  }

  // ═══════════════════════════════════════════════════════════════
  // LEGACY METHOD (for backward compatibility)
  // ═══════════════════════════════════════════════════════════════
  
  Future<void> speakWarning(String text) async {
    if (!_isInitialized || text.isEmpty) return;

    try {
      if (_isSpeaking) {
        await _flutterTts.stop();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await _flutterTts.speak(text);
      print('🔊 TTS: "$text"');
    } catch (e) {
      print('❌ TTS error: $e');
    }
  }

  // Urgent announcements (faster speech rate)
  Future<void> speakUrgent(String text) async {
    if (!_isInitialized) return;

    try {
      await _flutterTts.setSpeechRate(0.65);
      await speakWarning(text);
      await _flutterTts.setSpeechRate(0.55);
    } catch (e) {
      print('❌ TTS urgent error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (e) {
      print('TTS stop error: $e');
    }
  }

  bool get isSpeaking => _isSpeaking;
  bool get isInitialized => _isInitialized;

  void dispose() {
    stop();
    _isInitialized = false;
  }
}