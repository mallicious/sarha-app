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
import 'package:sarha_app/services/voice_navigation_services.dart';

// ===== SENSOR FUSION DATA =====

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

// ===== HAZARD DETECTION RESULT =====

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

// ===== SENSOR FUSION ENGINE =====

class SensorFusionEngine {
  // Thresholds are now relative to 0 (gravity removed)
  static const double POTHOLE_Z_THRESHOLD = 6.0;
  static const double SPEED_BUMP_Z_THRESHOLD = 4.0;
  static const double ROUGH_ROAD_THRESHOLD = 2.5;
  static const double SHARP_TURN_ROTATION_THRESHOLD = 1.5;
  static const double SWERVE_Y_THRESHOLD = 5.0;
  static const double MIN_SPEED_KMH = 5.0;
  static const double MAX_SPEED_KMH = 100.0;

  final List<SensorFusionData> _recentData = [];
  static const int DATA_WINDOW_SIZE = 10;

  // Cooldown to prevent rapid-fire detections
  DateTime? _lastDetection;
  static const Duration DETECTION_COOLDOWN = Duration(seconds: 5);

  HazardDetectionResult? analyzeHazard(SensorFusionData data) {
    _recentData.add(data);
    if (_recentData.length > DATA_WINDOW_SIZE) {
      _recentData.removeAt(0);
    }

    // Must be moving to detect hazards
    if (data.speed < MIN_SPEED_KMH) return null;

    // Cooldown between detections
    if (_lastDetection != null &&
        DateTime.now().difference(_lastDetection!) < DETECTION_COOLDOWN) {
      return null;
    }

    final avgZ =
        _recentData.map((d) => d.accelerationZ).reduce((a, b) => a + b) /
            _recentData.length;
    final avgRotation =
        _recentData.map((d) => d.rotationZ.abs()).reduce((a, b) => a + b) /
            _recentData.length;

    HazardDetectionResult? result;

    if (_detectPothole(data, avgRotation)) {
      result = HazardDetectionResult(
        hazardType: 'Pothole',
        confidence:
            _calculateConfidence(data.accelerationZ, POTHOLE_Z_THRESHOLD, 15.0),
        description: 'Deep pothole detected - sharp vertical impact',
        color: const Color(0xFFE53935),
      );
    } else if (_detectSpeedBump(data)) {
      result = HazardDetectionResult(
        hazardType: 'Speed Bump',
        confidence: _calculateConfidence(
            data.accelerationZ, SPEED_BUMP_Z_THRESHOLD, 10.0),
        description: 'Speed bump ahead - reduce speed',
        color: const Color(0xFFFB8C00),
      );
    } else if (_detectRoughRoad(data, avgZ)) {
      result = HazardDetectionResult(
        hazardType: 'Rough Road',
        confidence:
            _calculateConfidence(data.accelerationZ, ROUGH_ROAD_THRESHOLD, 8.0),
        description: 'Damaged road surface - poor maintenance',
        color: const Color(0xFFF57C00),
      );
    } else if (_detectSharpTurn(data)) {
      result = HazardDetectionResult(
        hazardType: 'Sharp Turn',
        confidence: _calculateConfidence(
            data.rotationZ.abs(), SHARP_TURN_ROTATION_THRESHOLD, 4.0),
        description: 'Sharp curve - slow down',
        color: const Color(0xFFFDD835),
      );
    } else if (_detectSwerve(data)) {
      result = HazardDetectionResult(
        hazardType: 'Obstacle Avoidance',
        confidence: _calculateConfidence(
            data.accelerationY.abs(), SWERVE_Y_THRESHOLD, 12.0),
        description: 'Driver swerved - possible hazard ahead',
        color: const Color(0xFFFF6F00),
      );
    } else if (_isWaterPattern(data)) {
      result = HazardDetectionResult(
        hazardType: 'Water Hazard',
        confidence: 0.70,
        description: 'Flooded area or large puddle detected',
        color: const Color(0xFF1E88E5),
      );
    }

    if (result != null) {
      _lastDetection = DateTime.now();
    }

    return result;
  }

  double _calculateConfidence(
      double value, double minThreshold, double maxThreshold) {
    final normalized = ((value - minThreshold) / (maxThreshold - minThreshold))
        .clamp(0.0, 1.0);
    return 0.5 + (normalized * 0.5);
  }

  bool _detectPothole(SensorFusionData data, double avgRotation) {
    return data.accelerationZ > POTHOLE_Z_THRESHOLD &&
        data.rotationX.abs() < 1.0 &&
        avgRotation < 0.8;
  }

  bool _detectSpeedBump(SensorFusionData data) {
    return data.accelerationZ > SPEED_BUMP_Z_THRESHOLD &&
        data.accelerationZ < POTHOLE_Z_THRESHOLD &&
        data.rotationX > 0.5 &&
        data.rotationX < 2.0;
  }

  bool _detectRoughRoad(SensorFusionData data, double avgZ) {
    return data.accelerationZ > ROUGH_ROAD_THRESHOLD &&
        data.accelerationZ < SPEED_BUMP_Z_THRESHOLD &&
        _isVibrationPattern();
  }

  bool _detectSharpTurn(SensorFusionData data) {
    return data.rotationZ.abs() > SHARP_TURN_ROTATION_THRESHOLD &&
        data.accelerationY.abs() > 3.0 &&
        data.speed > 30.0;
  }

  bool _detectSwerve(SensorFusionData data) {
    return data.accelerationY.abs() > SWERVE_Y_THRESHOLD &&
        data.rotationZ.abs() > 1.5 &&
        data.accelerationZ < ROUGH_ROAD_THRESHOLD;
  }

  bool _isVibrationPattern() {
    if (_recentData.length < 5) return false;
    int vibrationCount = _recentData
        .take(5)
        .where((d) =>
            d.accelerationZ > ROUGH_ROAD_THRESHOLD &&
            d.accelerationZ < SPEED_BUMP_Z_THRESHOLD)
        .length;
    return vibrationCount >= 3;
  }

  bool _isWaterPattern(SensorFusionData data) {
    if (_recentData.length < 6) return false;
    int spikeCount = _recentData
        .take(6)
        .where((d) => d.accelerationZ > 4.0 && d.accelerationZ < 7.0)
        .length;
    return spikeCount >= 4;
  }
}

// ===== TTS SERVICE =====

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  DateTime? _lastAnnouncement;

  TTSService() {
    _initialize();
  }

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

    if (_lastAnnouncement != null &&
        DateTime.now().difference(_lastAnnouncement!) <
            const Duration(seconds: 5)) {
      return;
    }

    String message = 'Road hazard detected.';
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
    }

    await _flutterTts.speak(message);
    _lastAnnouncement = DateTime.now();
  }

  void dispose() => _flutterTts.stop();
}

// ===== MAIN MAP DETECTION SCREEN =====

class MapDetectionScreen extends StatefulWidget {
  const MapDetectionScreen({super.key});

  @override
  State<MapDetectionScreen> createState() => _MapDetectionScreenState();
}

class _MapDetectionScreenState extends State<MapDetectionScreen> {
  static const Color softLavender = Color(0xFFA7B5F4);
  static const Color coral = Color(0xFFFF9B85);
  static const Color cream = Color(0xFFFAF8F5);
  static const Color deepPurple = Color(0xFF4A4063);
  static const Color lightPurple = Color(0xFFD1D5F7);

  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isDetecting = false;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<Position>? _positionSubscription;

  final SensorFusionEngine _fusionEngine = SensorFusionEngine();
  final VoiceNavigationService _voiceService = VoiceNavigationService();
  late final TTSService _ttsService;

  double _accelX = 0.0, _accelY = 0.0, _accelZ = 0.0;
  double _gyroX = 0.0, _gyroY = 0.0, _gyroZ = 0.0;
  double _currentSpeed = 0.0;

  // Gravity-removed magnitude for display
  double _netAcceleration = 0.0;

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
    _ttsService = TTSService();
    _requestPermissions();
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _positionSubscription?.cancel();
    _isDetecting = false;
    _voiceService.stopNavigation();
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    try {
      final locationStatus = await Permission.location.request();
      if (locationStatus.isGranted) {
        await _getCurrentLocation();
        _startLocationTracking();
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Location permission denied', coral);
      }
    } catch (e) {
      _showSnackBar('Error requesting permissions: $e', coral);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
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
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
        _currentSpeed = position.speed * 3.6;
      });
    });
  }

  void _toggleDetection() {
    setState(() => _isDetecting = !_isDetecting);

    if (_isDetecting) {
      _startSensorFusion();
      _voiceService.startNavigation();
      _showSnackBar('Sensor Fusion & Voice Navigation Active', Colors.green);
    } else {
      _stopSensorFusion();
      _voiceService.stopNavigation();
      _showSnackBar('Detection Paused', coral);
    }
  }

  void _startSensorFusion() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      if (!mounted || !_isDetecting) return;
      setState(() {
        _accelX = event.x;
        _accelY = event.y;
        _accelZ = event.z;
      });
      _processSensorData();
    });

    _gyroscopeSubscription = gyroscopeEventStream().listen((event) {
      if (!mounted || !_isDetecting) return;
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
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
  }

  void _processSensorData() {
    if (_currentPosition == null || !_isDetecting) return;

    // Remove gravity from the magnitude - earth's gravity is ~9.8 m/s²
    const double gravity = 9.8;
    final rawMagnitude =
        sqrt(_accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ);
    final netMagnitude = (rawMagnitude - gravity).clamp(0.0, double.infinity);

    setState(() => _netAcceleration = netMagnitude);

    // Only process if there's meaningful movement above gravity
    if (netMagnitude < 0.5) return;

    final fusionData = SensorFusionData(
      accelerationZ: netMagnitude,
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
    if (_currentPosition == null || !_isDetecting) return;

    final markerId = 'hazard_${DateTime.now().millisecondsSinceEpoch}';
    final position =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

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

      if (!mounted) return;

      setState(() {
        _hazardCounts[result.hazardType] =
            (_hazardCounts[result.hazardType] ?? 0) + 1;

        _hazardMarkers.add(Marker(
          markerId: MarkerId(markerId),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              _getMarkerHue(result.hazardType)),
          infoWindow: InfoWindow(
            title: result.hazardType,
            snippet:
                '${(result.confidence * 100).toStringAsFixed(0)}% confidence',
          ),
        ));
      });

      await _ttsService.speakWarning(result.hazardType);
    } catch (e) {
      print('Error saving hazard: $e');
    }
  }

  double _getMarkerHue(String hazardType) {
    switch (hazardType) {
      case 'Pothole':
        return BitmapDescriptor.hueRed;
      case 'Speed Bump':
        return BitmapDescriptor.hueOrange;
      case 'Rough Road':
        return BitmapDescriptor.hueYellow;
      case 'Sharp Turn':
        return BitmapDescriptor.hueViolet;
      case 'Water Hazard':
        return BitmapDescriptor.hueBlue;
      default:
        return BitmapDescriptor.hueRose;
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text('Sensor Fusion Detection',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: softLavender,
        foregroundColor: deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showSensorFusionInfo(),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: coral))
          : Stack(
              children: [
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
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _buildStatusPanel(),
                ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isDetecting
                  ? Colors.green[50]
                  : lightPurple.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isDetecting ? Icons.sensors : Icons.sensors_off,
              color: _isDetecting
                  ? Colors.green[600]
                  : deepPurple.withOpacity(0.5),
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDetecting ? 'Sensor Fusion Active' : 'System Standby',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: deepPurple),
                ),
                Text(
                  '${_hazardMarkers.length} hazards detected',
                  style: TextStyle(
                      fontSize: 12, color: deepPurple.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [softLavender, lightPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentSpeed.toStringAsFixed(0)} km/h',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: deepPurple.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, color: coral, size: 20),
              const SizedBox(width: 8),
              const Text(
                'SENSOR FUSION READINGS',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSensorReading(
                  'Net Accel', _netAcceleration.toStringAsFixed(2), coral),
              _buildSensorReading(
                  'Gyro', _gyroZ.toStringAsFixed(2), softLavender),
              _buildSensorReading(
                  'Speed',
                  '${_currentSpeed.toStringAsFixed(0)} km/h',
                  Colors.green[300]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorReading(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _toggleDetection,
              icon: Icon(
                  _isDetecting ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 24),
              label: Text(
                _isDetecting ? 'PAUSE DETECTION' : 'START DETECTION',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDetecting ? coral : Colors.green[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: softLavender.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.science_rounded, color: softLavender, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Sensor Fusion Technology',
                  style: TextStyle(
                      color: deepPurple,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SARHA uses advanced sensor fusion to detect road hazards:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: deepPurple,
                    fontSize: 15),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.phone_android_rounded,
                  'Accelerometer - Detects vertical jolts', softLavender),
              _buildInfoRow(Icons.rotate_right_rounded,
                  'Gyroscope - Measures rotation & tilt', coral),
              _buildInfoRow(Icons.location_on_rounded,
                  'GPS - Provides location & speed', Colors.green[400]!),
              const SizedBox(height: 16),
              Text(
                'Detects with 85%+ accuracy:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: deepPurple,
                    fontSize: 15),
              ),
              const SizedBox(height: 8),
              _buildHazardType('Potholes'),
              _buildHazardType('Speed bumps'),
              _buildHazardType('Rough road surfaces'),
              _buildHazardType('Sharp turns'),
              _buildHazardType('Water hazards'),
              _buildHazardType('Obstacle avoidance patterns'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: coral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: deepPurple.withOpacity(0.8), fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildHazardType(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green[400], size: 18),
          const SizedBox(width: 8),
          Text(text,
              style:
                  TextStyle(color: deepPurple.withOpacity(0.7), fontSize: 14)),
        ],
      ),
    );
  }
}
