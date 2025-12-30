// lib/screen/unified_detection_screen.dart
// THE ULTIMATE COMBINED DETECTION SYSTEM

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';
import 'package:sarha_app/services/voice_navigation_services.dart';

// Reuse sensor fusion classes
class SensorFusionData {
  final double accelerationZ;
  final double accelerationY;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double speed;
  final DateTime timestamp;

  SensorFusionData({
    required this.accelerationZ,
    required this.accelerationY,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.speed,
    required this.timestamp,
  });
}

class HazardDetectionResult {
  final String hazardType;
  final double confidence;
  final String description;
  final Color color;

  HazardDetectionResult({
    required this.hazardType,
    required this.confidence,
    required this.description,
    required this.color,
  });
}

class SensorFusionEngine {
  static const double POTHOLE_Z_THRESHOLD = 12.0;
  static const double SPEED_BUMP_Z_THRESHOLD = 10.0;
  static const double ROUGH_ROAD_THRESHOLD = 8.0;
  static const double SHARP_TURN_ROTATION_THRESHOLD = 1.5;
  static const double SWERVE_Y_THRESHOLD = 5.0;
  static const double MIN_SPEED_KMH = 5.0;

  final List<SensorFusionData> _recentData = [];
  static const int DATA_WINDOW_SIZE = 10;

  HazardDetectionResult? analyzeHazard(SensorFusionData data) {
    _recentData.add(data);
    if (_recentData.length > DATA_WINDOW_SIZE) _recentData.removeAt(0);
    if (data.speed < MIN_SPEED_KMH) return null;

    // POTHOLE
    if (data.accelerationZ > POTHOLE_Z_THRESHOLD) {
      return HazardDetectionResult(
        hazardType: 'Pothole',
        confidence: _calculateConfidence(data.accelerationZ, POTHOLE_Z_THRESHOLD, 25.0),
        description: 'Deep pothole detected',
        color: const Color(0xFFE53935),
      );
    }

    // SPEED BUMP
    if (data.accelerationZ > SPEED_BUMP_Z_THRESHOLD && data.accelerationZ < POTHOLE_Z_THRESHOLD) {
      return HazardDetectionResult(
        hazardType: 'Speed Bump',
        confidence: _calculateConfidence(data.accelerationZ, SPEED_BUMP_Z_THRESHOLD, 18.0),
        description: 'Speed bump ahead',
        color: const Color(0xFFFB8C00),
      );
    }

    // ROUGH ROAD
    if (data.accelerationZ > ROUGH_ROAD_THRESHOLD) {
      return HazardDetectionResult(
        hazardType: 'Rough Road',
        confidence: _calculateConfidence(data.accelerationZ, ROUGH_ROAD_THRESHOLD, 14.0),
        description: 'Damaged road surface',
        color: const Color(0xFFF57C00),
      );
    }

    return null;
  }

  double _calculateConfidence(double value, double minThreshold, double maxThreshold) {
    final normalized = ((value - minThreshold) / (maxThreshold - minThreshold)).clamp(0.0, 1.0);
    return 0.5 + (normalized * 0.5);
  }
}

// ═══════════════════════════════════════════════════════════════
// UNIFIED DETECTION SCREEN
// ═══════════════════════════════════════════════════════════════

class UnifiedDetectionScreen extends StatefulWidget {
  const UnifiedDetectionScreen({super.key});

  @override
  State<UnifiedDetectionScreen> createState() => _UnifiedDetectionScreenState();
}

class _UnifiedDetectionScreenState extends State<UnifiedDetectionScreen> {
  // === CALM COLOR PALETTE ===
  static const Color softLavender = Color(0xFFA7B5F4);
  static const Color coral = Color(0xFFFF9B85);
  static const Color cream = Color(0xFFFAF8F5);
  static const Color deepPurple = Color(0xFF4A4063);
  static const Color lightPurple = Color(0xFFD1D5F7);

  // Camera (AR)
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  // Sensors (Motion Detection)
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<Position>? _positionSubscription;

  final SensorFusionEngine _fusionEngine = SensorFusionEngine();
  final VoiceNavigationService _voiceService = VoiceNavigationService();

  double _accelX = 0.0, _accelY = 0.0, _accelZ = 0.0;
  double _gyroX = 0.0, _gyroY = 0.0, _gyroZ = 0.0;
  double _currentSpeed = 0.0;

  // Location & Hazards
  Position? _currentPosition;
  List<Map<String, dynamic>> _nearbyHazards = [];
  final Set<Marker> _detectedHazards = {};

  // State
  bool _isDetecting = false;
  bool _showMap = false; // Toggle between camera and map view

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _positionSubscription?.cancel();
    _voiceService.stopNavigation();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // CAMERA INITIALIZATION
  // ═══════════════════════════════════════════════════════════

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      print('Camera error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // LOCATION & HAZARD LOADING
  // ═══════════════════════════════════════════════════════════

  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      _startLocationTracking();
      _loadNearbyHazards();
    } catch (e) {
      print('Location error: $e');
    }
  }

  void _startLocationTracking() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
        _currentSpeed = position.speed * 3.6;
      });
    });
  }

  Future<void> _loadNearbyHazards() async {
    if (_currentPosition == null) return;

    try {
      final snapshot = await _firestore
          .collection('hazards')
          .where('status', isEqualTo: 'pending')
          .limit(50)
          .get();

      final hazards = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final hazardLat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
        final hazardLon = (data['longitude'] as num?)?.toDouble() ?? 0.0;

        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          hazardLat,
          hazardLon,
        );

        if (distance <= 500) {
          hazards.add({
            'id': doc.id,
            'type': data['type'] ?? 'Hazard',
            'description': data['description'] ?? '',
            'distance': distance,
            'latitude': hazardLat,
            'longitude': hazardLon,
          });
        }
      }

      hazards.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      if (mounted) setState(() => _nearbyHazards = hazards);
    } catch (e) {
      print('Error loading hazards: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // START/STOP DETECTION
  // ═══════════════════════════════════════════════════════════

  void _toggleDetection() {
    setState(() => _isDetecting = !_isDetecting);

    if (_isDetecting) {
      _startSensorFusion();
      _voiceService.startNavigation();
      _showSnackBar('🎯 AR + Sensor Fusion + Voice Navigation ACTIVE', Colors.green);
    } else {
      _stopSensorFusion();
      _voiceService.stopNavigation();
      _showSnackBar('Detection Paused', coral);
    }
  }

  void _startSensorFusion() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      setState(() {
        _accelX = event.x;
        _accelY = event.y;
        _accelZ = event.z;
      });
      _processSensorData();
    });

    _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
      setState(() {
        _gyroX = event.x;
        _gyroY = event.y;
        _gyroZ = event.z;
      });
    });
  }

  void _stopSensorFusion() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
  }

  void _processSensorData() {
    if (_currentPosition == null) return;

    final magnitudeZ = sqrt(_accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ);

    final fusionData = SensorFusionData(
      accelerationZ: magnitudeZ,
      accelerationY: _accelY.abs(),
      rotationX: _gyroX,
      rotationY: _gyroY,
      rotationZ: _gyroZ,
      speed: _currentSpeed,
      timestamp: DateTime.now(),
    );

    final hazardResult = _fusionEngine.analyzeHazard(fusionData);

    if (hazardResult != null && hazardResult.confidence > 0.65) {
      _handleHazardDetection(hazardResult);
    }
  }

  Future<void> _handleHazardDetection(HazardDetectionResult result) async {
    if (_currentPosition == null) return;

    try {
      await _firestore.collection('hazards').add({
        'type': result.hazardType,
        'description': result.description,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'confidence': result.confidence,
        'speed': _currentSpeed,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': _auth.currentUser?.uid,
        'detectionMethod': 'sensor_fusion',
        'status': 'pending',
      });

      await _voiceService.announceImmediateHazard(result.hazardType);

      _showSnackBar('${result.hazardType} detected!', result.color);
    } catch (e) {
      print('Error saving hazard: $e');
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // UI BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Hazard Detection', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: softLavender,
        foregroundColor: deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.camera_alt_rounded : Icons.map_rounded),
            onPressed: () => setState(() => _showMap = !_showMap),
            tooltip: _showMap ? 'Camera View' : 'Map View',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadNearbyHazards,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background: Camera OR Map
          if (_showMap)
            _buildMapView()
          else
            _buildCameraView(),

          // Top Status Panel
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildStatusPanel(),
          ),

          // AR Hazard Overlays (only in camera mode)
          if (!_showMap && _nearbyHazards.isNotEmpty)
            ..._nearbyHazards.asMap().entries.map((entry) {
              return _buildARHazardMarker(entry.value, entry.key);
            }).toList(),

          // Sensor Readings (when detecting)
          if (_isDetecting)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: _buildSensorPanel(),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomControls(),
    );
  }

  Widget _buildCameraView() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: coral),
            const SizedBox(height: 16),
            const Text('Initializing camera...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _buildMapView() {
    if (_currentPosition == null) {
      return Center(child: CircularProgressIndicator(color: coral));
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 16,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: _detectedHazards,
    );
  }

  Widget _buildStatusPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isDetecting ? Colors.green : softLavender, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _isDetecting ? Icons.radar_rounded : Icons.sensors_off_rounded,
                color: _isDetecting ? Colors.green : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isDetecting ? '🎯 FULL DETECTION ACTIVE' : 'SYSTEM STANDBY',
                      style: TextStyle(
                        color: _isDetecting ? Colors.green : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${_nearbyHazards.length} hazards in range',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: coral,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentSpeed.toStringAsFixed(0)} km/h',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (_isDetecting) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat(Icons.camera_alt_rounded, 'Camera', _isCameraInitialized ? 'ON' : 'OFF'),
                _buildMiniStat(Icons.sensors_rounded, 'Sensors', 'ON'),
                _buildMiniStat(Icons.volume_up_rounded, 'Voice', _voiceService.voiceEnabled ? 'ON' : 'OFF'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String status) {
    final isActive = status == 'ON';
    return Row(
      children: [
        Icon(icon, color: isActive ? Colors.green : Colors.grey, size: 16),
        const SizedBox(width: 4),
        Text(
          '$label: $status',
          style: TextStyle(
            color: isActive ? Colors.green : Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildARHazardMarker(Map<String, dynamic> hazard, int index) {
    final distance = hazard['distance'] as double;
    final type = hazard['type'] as String;

    final verticalPosition = 150.0 + (distance * 1.5);
    final horizontalOffset = (index % 3) * 120.0 + 30.0;

    return Positioned(
      top: verticalPosition,
      left: horizontalOffset,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _getHazardColor(type),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              type.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            ),
            Text(
              '${distance.toStringAsFixed(0)}m',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Color _getHazardColor(String type) {
    switch (type.toLowerCase()) {
      case 'pothole':
        return const Color(0xFFE53935).withOpacity(0.9);
      case 'flooding':
        return const Color(0xFF1E88E5).withOpacity(0.9);
      case 'roadwork':
        return const Color(0xFFFB8C00).withOpacity(0.9);
      default:
        return coral.withOpacity(0.9);
    }
  }

  Widget _buildSensorPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: deepPurple.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            '⚡ SENSOR FUSION ACTIVE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSensorReading('Accel', _accelZ.toStringAsFixed(1), coral),
              _buildSensorReading('Gyro', _gyroZ.toStringAsFixed(2), softLavender),
              _buildSensorReading('Speed', '${_currentSpeed.toStringAsFixed(0)}', Colors.green[300]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorReading(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        border: Border(top: BorderSide(color: softLavender.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _toggleDetection,
              icon: Icon(_isDetecting ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 24),
              label: Text(
                _isDetecting ? 'PAUSE' : 'START DETECTION',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDetecting ? coral : Colors.green[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}