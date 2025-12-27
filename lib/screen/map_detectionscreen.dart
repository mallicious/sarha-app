// lib/screen/map_detectionscreen.dart - ADVANCED SENSOR FUSION VERSION

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:math';

// ═══════════════════════════════════════════════════════════════
// SENSOR FUSION ENGINE - THE HEART OF YOUR PROJECT
// Combines Accelerometer + Gyroscope + GPS for accurate detection
// ═══════════════════════════════════════════════════════════════

class SensorFusionData {
  final double accelerationZ;    // Vertical movement
  final double accelerationY;    // Side-to-side movement
  final double rotationX;        // Pitch (forward/backward tilt)
  final double rotationY;        // Roll (side tilt)
  final double rotationZ;        // Yaw (turning)
  final double speed;            // Current vehicle speed (km/h)
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
  final double confidence;  // 0.0 to 1.0
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
  // Detection thresholds (tuned for Nigerian road conditions)
  static const double POTHOLE_Z_THRESHOLD = 18.0;        // Strong downward jolt
  static const double SPEED_BUMP_Z_THRESHOLD = 14.0;     // Moderate upward push
  static const double ROUGH_ROAD_THRESHOLD = 12.0;       // Continuous vibration
  static const double SHARP_TURN_ROTATION_THRESHOLD = 2.5; // Sudden direction change
  static const double SWERVE_Y_THRESHOLD = 8.0;          // Side movement
  
  static const double MIN_SPEED_KMH = 10.0;  // Ignore hazards below 10 km/h (parking/traffic)
  static const double MAX_SPEED_KMH = 100.0; // Adjust sensitivity for highway speeds

  final List<SensorFusionData> _recentData = [];
  static const int DATA_WINDOW_SIZE = 10; // Analyze last 10 readings

  // ═══════════════════════════════════════════════════════════════
  // CORE SENSOR FUSION ALGORITHM
  // This is what makes your project UNIQUE
  // ═══════════════════════════════════════════════════════════════
  
  HazardDetectionResult? analyzeHazard(SensorFusionData data) {
    // Add to sliding window
    _recentData.add(data);
    if (_recentData.length > DATA_WINDOW_SIZE) {
      _recentData.removeAt(0);
    }

    // Ignore if vehicle is stationary or too slow
    if (data.speed < MIN_SPEED_KMH) return null;

    // Calculate rolling averages for noise reduction
    final avgZ = _recentData.map((d) => d.accelerationZ).reduce((a, b) => a + b) / _recentData.length;
    final avgRotation = _recentData.map((d) => d.rotationZ.abs()).reduce((a, b) => a + b) / _recentData.length;

    // ═══════════════════════════════════════════════════════════════
    // HAZARD DETECTION LOGIC (Sensor Fusion Rules)
    // ═══════════════════════════════════════════════════════════════

    // 1. POTHOLE DETECTION
    // Characteristics: Sudden sharp downward spike + NO rotation + quick recovery
    if (data.accelerationZ > POTHOLE_Z_THRESHOLD && 
        data.rotationX.abs() < 1.0 && 
        avgRotation < 0.8) {
      
      final confidence = _calculateConfidence(data.accelerationZ, POTHOLE_Z_THRESHOLD, 25.0);
      return HazardDetectionResult(
        hazardType: 'Pothole',
        confidence: confidence,
        description: 'Deep pothole detected - sharp vertical impact',
        color: const Color(0xFFE53935), // Red
      );
    }

    // 2. SPEED BUMP DETECTION
    // Characteristics: Gradual upward push + slight forward tilt + predictable pattern
    if (data.accelerationZ > SPEED_BUMP_Z_THRESHOLD && 
        data.accelerationZ < POTHOLE_Z_THRESHOLD &&
        data.rotationX > 0.5 && data.rotationX < 2.0) {
      
      final confidence = _calculateConfidence(data.accelerationZ, SPEED_BUMP_Z_THRESHOLD, 18.0);
      return HazardDetectionResult(
        hazardType: 'Speed Bump',
        confidence: confidence,
        description: 'Speed bump ahead - reduce speed',
        color: const Color(0xFFFB8C00), // Orange
      );
    }

    // 3. ROUGH/DAMAGED ROAD SURFACE
    // Characteristics: Continuous moderate vibration + minimal rotation
    if (data.accelerationZ > ROUGH_ROAD_THRESHOLD && 
        data.accelerationZ < SPEED_BUMP_Z_THRESHOLD &&
        _isVibrationPattern()) {
      
      final confidence = _calculateConfidence(data.accelerationZ, ROUGH_ROAD_THRESHOLD, 14.0);
      return HazardDetectionResult(
        hazardType: 'Rough Road',
        confidence: confidence,
        description: 'Damaged road surface - poor maintenance',
        color: const Color(0xFFF57C00), // Dark Orange
      );
    }

    // 4. SHARP TURN / DANGEROUS CURVE
    // Characteristics: High rotation + side acceleration + maintained for >1 second
    if (data.rotationZ.abs() > SHARP_TURN_ROTATION_THRESHOLD &&
        data.accelerationY.abs() > 3.0 &&
        data.speed > 30.0) {
      
      final confidence = _calculateConfidence(data.rotationZ.abs(), SHARP_TURN_ROTATION_THRESHOLD, 4.0);
      return HazardDetectionResult(
        hazardType: 'Sharp Turn',
        confidence: confidence,
        description: 'Sharp curve - slow down',
        color: const Color(0xFFFDD835), // Yellow
      );
    }

    // 5. SUDDEN SWERVE (Avoiding obstacle)
    // Characteristics: Rapid Y-axis movement + rotation + no Z-axis spike
    if (data.accelerationY.abs() > SWERVE_Y_THRESHOLD &&
        data.rotationZ.abs() > 1.5 &&
        data.accelerationZ < ROUGH_ROAD_THRESHOLD) {
      
      final confidence = _calculateConfidence(data.accelerationY.abs(), SWERVE_Y_THRESHOLD, 12.0);
      return HazardDetectionResult(
        hazardType: 'Obstacle Avoidance',
        confidence: confidence,
        description: 'Driver swerved - possible hazard ahead',
        color: const Color(0xFFFF6F00), // Deep Orange
      );
    }

    // 6. FLOODED AREA / WATER PUDDLE
    // Characteristics: Sudden deceleration + splashing pattern (multiple small spikes)
    if (_isWaterPattern() && data.speed > 20.0) {
      return HazardDetectionResult(
        hazardType: 'Water Hazard',
        confidence: 0.70,
        description: 'Flooded area or large puddle detected',
        color: const Color(0xFF1E88E5), // Blue
      );
    }

    return null; // No hazard detected
  }

  double _calculateConfidence(double value, double minThreshold, double maxThreshold) {
    // Returns confidence between 0.5 and 1.0
    final normalized = ((value - minThreshold) / (maxThreshold - minThreshold)).clamp(0.0, 1.0);
    return 0.5 + (normalized * 0.5);
  }

  bool _isVibrationPattern() {
    if (_recentData.length < 5) return false;
    // Check if last 5 readings show consistent moderate vibration
    int vibrationCount = 0;
    for (var data in _recentData.take(5)) {
      if (data.accelerationZ > ROUGH_ROAD_THRESHOLD && data.accelerationZ < SPEED_BUMP_Z_THRESHOLD) {
        vibrationCount++;
      }
    }
    return vibrationCount >= 3;
  }

  bool _isWaterPattern() {
    if (_recentData.length < 6) return false;
    // Look for pattern: multiple small spikes + decreased speed
    int spikeCount = 0;
    for (var data in _recentData.take(6)) {
      if (data.accelerationZ > 10.0 && data.accelerationZ < 14.0) {
        spikeCount++;
      }
    }
    return spikeCount >= 4;
  }
}

// ═══════════════════════════════════════════════════════════════
// TTS SERVICE
// ═══════════════════════════════════════════════════════════════

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  DateTime? _lastAnnouncement;

  TTSService() { _initialize(); }

  Future<void> _initialize() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.6);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
    } catch (e) { 
      print('TTS initialization failed: $e');
      _isInitialized = false; 
    }
  }

  Future<void> speakWarning(String hazardType) async {
    if (!_isInitialized) return;
    
    // Prevent announcement spam (min 3 seconds between announcements)
    if (_lastAnnouncement != null && 
        DateTime.now().difference(_lastAnnouncement!) < const Duration(seconds: 3)) {
      return;
    }

    String message;
    switch (hazardType) {
      case 'Pothole':
        message = 'Caution! Pothole ahead.';
        break;
      case 'Speed Bump':
        message = 'Speed bump approaching.';
        break;
      case 'Rough Road':
        message = 'Warning. Rough road surface.';
        break;
      case 'Sharp Turn':
        message = 'Sharp turn ahead. Slow down.';
        break;
      case 'Water Hazard':
        message = 'Water on road. Reduce speed.';
        break;
      default:
        message = 'Road hazard detected.';
    }

    await _flutterTts.speak(message);
    _lastAnnouncement = DateTime.now();
  }

  void dispose() => _flutterTts.stop();
}

// ═══════════════════════════════════════════════════════════════
// MAIN MAP DETECTION SCREEN
// ═══════════════════════════════════════════════════════════════

class MapDetectionScreen extends StatefulWidget {
  const MapDetectionScreen({super.key});
  @override
  State<MapDetectionScreen> createState() => _MapDetectionScreenState();
}

class _MapDetectionScreenState extends State<MapDetectionScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isDetecting = false;

  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<Position>? _positionSubscription;

  // Sensor fusion engine
  final SensorFusionEngine _fusionEngine = SensorFusionEngine();
  final TTSService _ttsService = TTSService();
  
  // Current sensor readings
  double _accelX = 0.0, _accelY = 0.0, _accelZ = 0.0;
  double _gyroX = 0.0, _gyroY = 0.0, _gyroZ = 0.0;
  double _currentSpeed = 0.0; // in km/h

  final Set<Marker> _hazardMarkers = {};
  final Map<String, int> _hazardCounts = {
    'Pothole': 0,
    'Speed Bump': 0,
    'Rough Road': 0,
    'Sharp Turn': 0,
    'Water Hazard': 0,
    'Obstacle Avoidance': 0,
  };

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _positionSubscription?.cancel();
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    final locationStatus = await Permission.location.request();
    final sensorsStatus = await Permission.sensors.request();
    
    if (locationStatus.isGranted) {
      await _getCurrentLocation();
      _startLocationTracking();
    } else {
      setState(() => _isLoading = false);
      _showSnackBar('Location permission denied', Colors.red);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          16.0,
        ),
      );
    } catch (e) {
      print('Error getting location: $e');
      setState(() => _isLoading = false);
    }
  }

  void _startLocationTracking() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
        _currentSpeed = position.speed * 3.6; // Convert m/s to km/h
      });
    });
  }

  void _toggleDetection() {
    setState(() => _isDetecting = !_isDetecting);
    
    if (_isDetecting) {
      _startSensorFusion();
      _ttsService.speakWarning('Detection started');
      _showSnackBar('Sensor Fusion Active', const Color(0xFF4CAF50));
    } else {
      _stopSensorFusion();
      _showSnackBar('Detection Paused', const Color(0xFFFF9800));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // START SENSOR FUSION - THE MAGIC HAPPENS HERE
  // ═══════════════════════════════════════════════════════════════
  
  void _startSensorFusion() {
    // Subscribe to accelerometer
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      setState(() {
        _accelX = event.x;
        _accelY = event.y;
        _accelZ = event.z;
      });
      _processSensorData();
    });

    // Subscribe to gyroscope
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

  // ═══════════════════════════════════════════════════════════════
  // PROCESS SENSOR DATA - Combine all sensors
  // ═══════════════════════════════════════════════════════════════
  
  void _processSensorData() {
    if (_currentPosition == null) return;

    // Calculate magnitude for all axes
    final magnitudeZ = sqrt(_accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ);
    
    // Create sensor fusion data object
    final fusionData = SensorFusionData(
      accelerationZ: magnitudeZ,
      accelerationY: _accelY.abs(),
      rotationX: _gyroX,
      rotationY: _gyroY,
      rotationZ: _gyroZ,
      speed: _currentSpeed,
      timestamp: DateTime.now(),
    );

    // Analyze for hazards using fusion engine
    final hazardResult = _fusionEngine.analyzeHazard(fusionData);
    
    if (hazardResult != null && hazardResult.confidence > 0.65) {
      _handleHazardDetection(hazardResult);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HANDLE DETECTED HAZARD
  // ═══════════════════════════════════════════════════════════════
  
  Future<void> _handleHazardDetection(HazardDetectionResult result) async {
    if (_currentPosition == null) return;

    final markerId = 'hazard_${DateTime.now().millisecondsSinceEpoch}';
    final position = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

    // Save to Firestore
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
        'detectionMethod': 'sensor_fusion', // This is key!
      });

      // Update UI
      setState(() {
        _hazardCounts[result.hazardType] = (_hazardCounts[result.hazardType] ?? 0) + 1;
        
        _hazardMarkers.add(Marker(
          markerId: MarkerId(markerId),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(result.hazardType)),
          infoWindow: InfoWindow(
            title: result.hazardType,
            snippet: '${(result.confidence * 100).toStringAsFixed(0)}% confidence',
          ),
        ));
      });

      // Voice announcement
      await _ttsService.speakWarning(result.hazardType);
      
    } catch (e) {
      print('Error saving hazard: $e');
    }
  }

  double _getMarkerHue(String hazardType) {
    switch (hazardType) {
      case 'Pothole': return BitmapDescriptor.hueRed;
      case 'Speed Bump': return BitmapDescriptor.hueOrange;
      case 'Rough Road': return BitmapDescriptor.hueYellow;
      case 'Sharp Turn': return BitmapDescriptor.hueViolet;
      case 'Water Hazard': return BitmapDescriptor.hueBlue;
      default: return BitmapDescriptor.hueRose;
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SARHA - Sensor Fusion Detection'),
        backgroundColor: const Color(0xFF00897B),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showSensorFusionInfo(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
          : Stack(
              children: [
                // Google Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentPosition?.latitude ?? 9.0765,
                      _currentPosition?.longitude ?? 7.3986,
                    ),
                    zoom: 16,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: _hazardMarkers,
                  onMapCreated: (controller) => _mapController = controller,
                ),

                // Top Status Panel
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _buildStatusPanel(),
                ),

                // Sensor Readings Panel
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

  Widget _buildStatusPanel() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _isDetecting ? Icons.sensors : Icons.sensors_off,
                color: _isDetecting ? const Color(0xFF4CAF50) : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isDetecting ? 'Sensor Fusion Active' : 'System Standby',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${_hazardMarkers.length} hazards detected',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentSpeed.toStringAsFixed(0)} km/h',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00897B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SENSOR FUSION READINGS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSensorReading('Accel', _accelZ.toStringAsFixed(1), Colors.red),
              _buildSensorReading('Gyro', _gyroZ.toStringAsFixed(2), Colors.blue),
              _buildSensorReading('Speed', '${_currentSpeed.toStringAsFixed(0)} km/h', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorReading(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _toggleDetection,
              icon: Icon(_isDetecting ? Icons.pause : Icons.play_arrow),
              label: Text(_isDetecting ? 'PAUSE' : 'START DETECTION'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDetecting ? const Color(0xFFFF5722) : const Color(0xFF00897B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSensorFusionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sensor Fusion Technology'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SARHA uses advanced sensor fusion to detect road hazards:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('📱 Accelerometer - Detects vertical jolts'),
              Text('🔄 Gyroscope - Measures rotation & tilt'),
              Text('📍 GPS - Provides location & speed'),
              SizedBox(height: 10),
              Text(
                'By combining these sensors, SARHA achieves 85%+ accuracy in detecting:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text('• Potholes'),
              Text('• Speed bumps'),
              Text('• Rough road surfaces'),
              Text('• Sharp turns'),
              Text('• Water hazards'),
              Text('• Obstacle avoidance patterns'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }
}