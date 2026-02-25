import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';

class ActiveHazard {
  final String type;
  final String description;
  final double confidence;
  final Color color;
  final IconData icon;

  ActiveHazard({
    required this.type,
    required this.description,
    required this.confidence,
    required this.color,
    required this.icon,
  });
}

class ARService extends ChangeNotifier {
  bool _isActive = false;
  ActiveHazard? _activeHazard = null;
  int _hazardCount = 0;
  Timer? _clearHazardTimer;

  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSub;
  StreamSubscription<Position>? _positionSub;

  double _accelX = 0, _accelY = 0, _accelZ = 0;
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0;
  double _currentSpeed = 0;

  bool get isActive => _isActive;
  ActiveHazard? get activeHazard => _activeHazard;
  int get hazardCount => _hazardCount;

  static const double POTHOLE_THRESHOLD = 12.0;
  static const double SPEED_BUMP_THRESHOLD = 10.0;
  static const double ROUGH_ROAD_THRESHOLD = 8.0;
  static const double SHARP_TURN_THRESHOLD = 1.5;
  static const double MIN_SPEED = 5.0;

  void startDetection() {
    if (_isActive) return;
    _isActive = true;
    notifyListeners();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      _currentSpeed = position.speed * 3.6;
    });

    _accelerometerSub = accelerometerEventStream().listen((event) {
      _accelX = event.x;
      _accelY = event.y;
      _accelZ = event.z;
      _processSensorData();
    });

    _gyroscopeSub = gyroscopeEventStream().listen((event) {
      _gyroX = event.x;
      _gyroY = event.y;
      _gyroZ = event.z;
    });
  }

  void stopDetection() {
    _isActive = false;
    _accelerometerSub?.cancel();
    _gyroscopeSub?.cancel();
    _positionSub?.cancel();
    _clearHazardTimer?.cancel();
    _activeHazard = null;
    notifyListeners();
  }

  void _processSensorData() {
    if (_currentSpeed < MIN_SPEED) return;

    final magnitude = sqrt(_accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ);

    ActiveHazard? detected;

    if (magnitude > POTHOLE_THRESHOLD && _gyroX.abs() < 1.0) {
      detected = ActiveHazard(
        type: 'Pothole',
        description: 'Sharp vertical impact detected — slow down',
        confidence: _calcConfidence(magnitude, POTHOLE_THRESHOLD, 25.0),
        color: const Color(0xFFE53935),
        icon: Icons.dangerous_rounded,
      );
    } else if (magnitude > SPEED_BUMP_THRESHOLD && _gyroX > 0.5 && _gyroX < 2.0) {
      detected = ActiveHazard(
        type: 'Speed Bump',
        description: 'Speed bump ahead — reduce speed',
        confidence: _calcConfidence(magnitude, SPEED_BUMP_THRESHOLD, 18.0),
        color: const Color(0xFFFB8C00),
        icon: Icons.speed_rounded,
      );
    } else if (magnitude > ROUGH_ROAD_THRESHOLD) {
      detected = ActiveHazard(
        type: 'Rough Road',
        description: 'Damaged road surface detected',
        confidence: _calcConfidence(magnitude, ROUGH_ROAD_THRESHOLD, 14.0),
        color: const Color(0xFFF57C00),
        icon: Icons.warning_amber_rounded,
      );
    } else if (_gyroZ.abs() > SHARP_TURN_THRESHOLD && _accelY.abs() > 3.0 && _currentSpeed > 30) {
      detected = ActiveHazard(
        type: 'Sharp Turn',
        description: 'Sharp curve ahead — slow down',
        confidence: _calcConfidence(_gyroZ.abs(), SHARP_TURN_THRESHOLD, 4.0),
        color: const Color(0xFFFDD835),
        icon: Icons.turn_right_rounded,
      );
    }

    if (detected != null && detected.confidence > 0.65) {
      _activeHazard = detected;
      _hazardCount++;
      notifyListeners();

      _saveHazardToFirestore(detected);

      _clearHazardTimer?.cancel();
      _clearHazardTimer = Timer(const Duration(seconds: 4), () {
        _activeHazard = null;
        notifyListeners();
      });
    }
  }

  double _calcConfidence(double value, double min, double max) {
    final normalized = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return 0.5 + (normalized * 0.5);
  }

  Future<void> _saveHazardToFirestore(ActiveHazard hazard) async {
    try {
      final position = await Geolocator.getCurrentPosition();
      await FirebaseFirestore.instance.collection('hazards').add({
        'type': hazard.type,
        'description': hazard.description,
        'confidence': hazard.confidence,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'detectionMethod': 'ar_sensor_fusion',
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('Failed to save AR hazard: $e');
    }
  }

  @override
  void dispose() {
    stopDetection();
    super.dispose();
  }
}