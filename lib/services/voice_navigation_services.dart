// lib/services/voice_navigation_service.dart

import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as Math;

class VoiceNavigationService {
  static final VoiceNavigationService _instance = VoiceNavigationService._internal();
  factory VoiceNavigationService() => _instance;
  VoiceNavigationService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isInitialized = false;
  bool _isRunning = false;
  bool _voiceEnabled = true;
  
  Position? _currentPosition;
  List<Map<String, dynamic>> _nearbyHazards = [];
  final Set<String> _announcedHazards = {}; // Track already announced hazards
  
  Timer? _navigationTimer;
  StreamSubscription<Position>? _positionSubscription;

  // Distance thresholds for announcements (in meters)
  static const double ALERT_DISTANCE_FAR = 500.0;
  static const double ALERT_DISTANCE_MEDIUM = 200.0;
  static const double ALERT_DISTANCE_NEAR = 100.0;
  static const double ALERT_DISTANCE_VERY_NEAR = 50.0;
  static const double ALERT_DISTANCE_IMMEDIATE = 20.0;
  static const double HAZARD_PASSED_DISTANCE = 30.0;

  // ═══════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5); // Slightly slower for clarity
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      // Load voice preference from settings
      final prefs = await SharedPreferences.getInstance();
      _voiceEnabled = prefs.getBool('soundAlerts') ?? true;
      
      _isInitialized = true;
      print('✅ Voice Navigation Service initialized');
    } catch (e) {
      print('❌ TTS initialization failed: $e');
      _isInitialized = false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // START/STOP NAVIGATION
  // ═══════════════════════════════════════════════════════════

  Future<void> startNavigation() async {
    if (!_isInitialized) await initialize();
    if (_isRunning) return;

    _isRunning = true;
    _announcedHazards.clear();
    
    await _speak("Voice navigation activated. Stay alert for hazards.");
    
    // Start location tracking
    _startLocationTracking();
    
    // Start periodic hazard checking
    _navigationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkNearbyHazards();
    });

    print('🎤 Voice Navigation STARTED');
  }

  Future<void> stopNavigation() async {
    _isRunning = false;
    _navigationTimer?.cancel();
    _positionSubscription?.cancel();
    _announcedHazards.clear();
    _nearbyHazards.clear();
    
    await _speak("Voice navigation stopped.");
    print('🛑 Voice Navigation STOPPED');
  }

  void _startLocationTracking() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      _currentPosition = position;
      _updateHazardDistances();
    });
  }

  // ═══════════════════════════════════════════════════════════
  // HAZARD DETECTION & MONITORING
  // ═══════════════════════════════════════════════════════════

  Future<void> _checkNearbyHazards() async {
    if (_currentPosition == null || !_isRunning) return;

    try {
      // Query hazards within 1km radius
      final snapshot = await _firestore
          .collection('hazards')
          .where('status', isEqualTo: 'pending')
          .limit(50)
          .get();

      final hazards = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final hazardLat = (data['latitude'] as num?)?.toDouble();
        final hazardLon = (data['longitude'] as num?)?.toDouble();

        if (hazardLat == null || hazardLon == null) continue;

        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          hazardLat,
          hazardLon,
        );

        // Only track hazards within 1km
        if (distance <= 1000) {
          hazards.add({
            'id': doc.id,
            'type': data['type'] ?? 'Hazard',
            'description': data['description'] ?? '',
            'distance': distance,
            'latitude': hazardLat,
            'longitude': hazardLon,
            'bearing': _calculateBearing(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              hazardLat,
              hazardLon,
            ),
          });
        }
      }

      // Sort by distance (nearest first)
      hazards.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      _nearbyHazards = hazards;
      _announceHazards();

    } catch (e) {
      print('Error checking hazards: $e');
    }
  }

  void _updateHazardDistances() {
    if (_currentPosition == null) return;

    for (var hazard in _nearbyHazards) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        hazard['latitude'] as double,
        hazard['longitude'] as double,
      );
      hazard['distance'] = distance;
    }

    // Re-sort by distance
    _nearbyHazards.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    _announceHazards();
  }

  // ═══════════════════════════════════════════════════════════
  // SMART ANNOUNCEMENT SYSTEM
  // ═══════════════════════════════════════════════════════════

  Future<void> _announceHazards() async {
    if (!_voiceEnabled || !_isRunning || _nearbyHazards.isEmpty) return;

    for (var hazard in _nearbyHazards) {
      final hazardId = hazard['id'] as String;
      final distance = hazard['distance'] as double;
      final type = hazard['type'] as String;
      final bearing = hazard['bearing'] as String;

      // Skip if already announced at this distance level
      final announcementKey = '$hazardId-${_getDistanceLevel(distance)}';
      if (_announcedHazards.contains(announcementKey)) continue;

      // Check if hazard has been passed
      if (distance > HAZARD_PASSED_DISTANCE && _announcedHazards.contains('$hazardId-passed')) {
        continue; // Already passed this hazard
      }

      // Announce based on distance
      String? message = _getAnnouncementMessage(type, distance, bearing);
      
      if (message != null) {
        await _speak(message);
        _announcedHazards.add(announcementKey);
        
        // Mark as passed if we're now behind it
        if (distance < HAZARD_PASSED_DISTANCE) {
          _announcedHazards.add('$hazardId-passed');
        }
        
        // Only announce one hazard at a time
        break;
      }
    }
  }

  String? _getAnnouncementMessage(String type, double distance, String bearing) {
    final typeFormatted = _formatHazardType(type);
    
    if (distance <= ALERT_DISTANCE_IMMEDIATE) {
      return "Warning! $typeFormatted directly ahead!";
    } else if (distance <= ALERT_DISTANCE_VERY_NEAR) {
      return "Caution! $typeFormatted in 50 meters, $bearing!";
    } else if (distance <= ALERT_DISTANCE_NEAR) {
      return "$typeFormatted ahead in 100 meters, $bearing. Slow down.";
    } else if (distance <= ALERT_DISTANCE_MEDIUM) {
      return "Hazard approaching. $typeFormatted in 200 meters, $bearing.";
    } else if (distance <= ALERT_DISTANCE_FAR) {
      return "$typeFormatted reported ahead in 500 meters.";
    }
    
    return null;
  }

  String _getDistanceLevel(double distance) {
    if (distance <= ALERT_DISTANCE_IMMEDIATE) return 'immediate';
    if (distance <= ALERT_DISTANCE_VERY_NEAR) return 'very-near';
    if (distance <= ALERT_DISTANCE_NEAR) return 'near';
    if (distance <= ALERT_DISTANCE_MEDIUM) return 'medium';
    if (distance <= ALERT_DISTANCE_FAR) return 'far';
    return 'very-far';
  }

  String _formatHazardType(String type) {
    switch (type.toLowerCase()) {
      case 'pothole':
        return 'Pothole';
      case 'flooding':
        return 'Flooded area';
      case 'speedbump':
      case 'speed bump':
        return 'Speed bump';
      case 'roadwork':
        return 'Road work';
      case 'debris':
        return 'Debris on road';
      case 'roughroad':
      case 'rough road':
        return 'Rough road surface';
      default:
        return 'Road hazard';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BEARING CALCULATION (Direction)
  // ═══════════════════════════════════════════════════════════

  String _calculateBearing(double startLat, double startLon, double endLat, double endLon) {
    final dLon = endLon - startLon;
    final y = Math.sin(dLon) * Math.cos(endLat);
    final x = Math.cos(startLat) * Math.sin(endLat) -
        Math.sin(startLat) * Math.cos(endLat) * Math.cos(dLon);
    
    final bearing = (Math.atan2(y, x) * 180 / Math.pi + 360) % 360;

    // Convert bearing to direction
    if (bearing >= 337.5 || bearing < 22.5) return 'ahead';
    if (bearing >= 22.5 && bearing < 67.5) return 'ahead right';
    if (bearing >= 67.5 && bearing < 112.5) return 'on right';
    if (bearing >= 112.5 && bearing < 157.5) return 'behind right';
    if (bearing >= 157.5 && bearing < 202.5) return 'behind';
    if (bearing >= 202.5 && bearing < 247.5) return 'behind left';
    if (bearing >= 247.5 && bearing < 292.5) return 'on left';
    return 'ahead left';
  }

  // ═══════════════════════════════════════════════════════════
  // IMMEDIATE HAZARD DETECTION (From Sensors)
  // ═══════════════════════════════════════════════════════════

  Future<void> announceImmediateHazard(String hazardType) async {
    if (!_voiceEnabled || !_isRunning) return;
    
    String message;
    switch (hazardType.toLowerCase()) {
      case 'pothole':
        message = 'Pothole detected! Brace for impact!';
        break;
      case 'speed bump':
        message = 'Speed bump detected!';
        break;
      case 'rough road':
        message = 'Rough road surface ahead!';
        break;
      case 'sharp turn':
        message = 'Sharp turn! Reduce speed!';
        break;
      case 'water hazard':
        message = 'Water on road! Slow down!';
        break;
      default:
        message = 'Road hazard detected ahead!';
    }
    
    await _speak(message);
  }

  // ═══════════════════════════════════════════════════════════
  // TTS CORE FUNCTIONS
  // ═══════════════════════════════════════════════════════════

  Future<void> _speak(String message) async {
    if (!_isInitialized || !_voiceEnabled) return;
    
    try {
      print('🔊 Voice: $message');
      await _flutterTts.speak(message);
    } catch (e) {
      print('TTS Error: $e');
    }
  }

  Future<void> setVoiceEnabled(bool enabled) async {
    _voiceEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundAlerts', enabled);
    
    if (enabled) {
      await _speak("Voice alerts enabled.");
    }
  }

  // ═══════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════

  bool get isRunning => _isRunning;
  bool get voiceEnabled => _voiceEnabled;
  List<Map<String, dynamic>> get nearbyHazards => _nearbyHazards;
  Position? get currentPosition => _currentPosition;

  // ═══════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════

  void dispose() {
    _navigationTimer?.cancel();
    _positionSubscription?.cancel();
    _flutterTts.stop();
  }
}

// Import dart:math for bearing calculation