import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:sarha_app/services/voice_navigation_services.dart';

class ARHazardScreen extends StatefulWidget {
  const ARHazardScreen({super.key});

  @override
  State<ARHazardScreen> createState() => _ARHazardScreenState();
}

class _ARHazardScreenState extends State<ARHazardScreen> {
  // === CALM COLOR PALETTE ===
  static const Color softLavender = Color(0xFFA7B5F4);
  static const Color coral = Color(0xFFFF9B85);
  static const Color cream = Color(0xFFFAF8F5);
  static const Color deepPurple = Color(0xFF4A4063);

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  Position? _currentPosition;
  List<Map<String, dynamic>> _nearbyHazards = [];
  bool _isScanning = false;
  final VoiceNavigationService _voiceService = VoiceNavigationService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _getCurrentLocation();
    _voiceService.startNavigation(); // Start voice navigation
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _voiceService.stopNavigation(); // Stop voice navigation
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showSnackBar('No camera found', coral);
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      print('Camera error: $e');
      _showSnackBar('Camera initialization failed', coral);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      _loadNearbyHazards();
    } catch (e) {
      print('Location error: $e');
    }
  }

  Future<void> _loadNearbyHazards() async {
    if (_currentPosition == null) return;

    setState(() => _isScanning = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('hazards')
          .where('status', isEqualTo: 'pending')
          .limit(20)
          .get();

      final hazards = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final hazardLat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
        final hazardLon = (data['longitude'] as num?)?.toDouble() ?? 0.0;

        // Calculate distance
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          hazardLat,
          hazardLon,
        );

        // Only show hazards within 100 meters
        if (distance <= 100) {
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

      // Sort by distance
      hazards.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      if (mounted) {
        setState(() {
          _nearbyHazards = hazards;
          _isScanning = false;
        });
      }
    } catch (e) {
      print('Error loading hazards: $e');
      setState(() => _isScanning = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AR Hazard View', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: softLavender,
        foregroundColor: deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadNearbyHazards,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          if (_isCameraInitialized && _cameraController != null)
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: CameraPreview(_cameraController!),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: coral),
                  const SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),

          // AR Overlay - Top Status
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildStatusPanel(),
          ),

          // AR Hazard Markers
          if (_nearbyHazards.isNotEmpty)
            ..._nearbyHazards.asMap().entries.map((entry) {
              final index = entry.key;
              final hazard = entry.value;
              return _buildARHazardMarker(hazard, index);
            }),

          // Bottom Info
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildBottomInfo(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: softLavender.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isScanning ? coral.withOpacity(0.3) : Colors.green[400]!.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isScanning ? Icons.search_rounded : Icons.center_focus_strong_rounded,
              color: _isScanning ? coral : Colors.green[400],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isScanning ? 'AR SCANNING...' : 'AR SCANNING',
                  style: TextStyle(
                    color: _isScanning ? coral : Colors.green[400],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${_nearbyHazards.length} hazards detected',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
              '${_nearbyHazards.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildARHazardMarker(Map<String, dynamic> hazard, int index) {
    final distance = hazard['distance'] as double;
    final type = hazard['type'] as String;
    
    // Position markers based on distance and index
    // Closer hazards appear lower on screen
    final verticalPosition = 200.0 + (distance * 2); // Further = higher on screen
    final horizontalOffset = (index % 3) * 120.0 + 30.0; // Spread horizontally

    return Positioned(
      top: verticalPosition,
      left: horizontalOffset,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _getHazardColor(type),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  type.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${distance.toStringAsFixed(0)}m',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
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
      case 'debris':
        return const Color(0xFFF57C00).withOpacity(0.9);
      case 'speed bump':
      case 'speedbump':
        return const Color(0xFF8E24AA).withOpacity(0.9);
      default:
        return coral.withOpacity(0.9);
    }
  }

  Widget _buildBottomInfo() {
    if (_nearbyHazards.isEmpty && !_isScanning) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: softLavender.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green[400], size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No hazards nearby. Safe to proceed!',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: coral.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: coral, size: 20),
              const SizedBox(width: 8),
              const Text(
                'HAZARDS IN RANGE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatBadge(Icons.warning_rounded, '${_nearbyHazards.where((h) => h['distance'] < 30).length}', 'Nearby', coral),
              _buildStatBadge(Icons.remove_red_eye_rounded, '${_nearbyHazards.where((h) => h['distance'] < 50).length}', 'In Range', Colors.orange[300]!),
              _buildStatBadge(Icons.camera_alt_rounded, '${_nearbyHazards.length}', 'Total', softLavender),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}