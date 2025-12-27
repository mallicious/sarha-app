// lib/screen/AR_hazardscreen.dart - WORKING WITHOUT PLUGIN ISSUES

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'dart:math';
import 'dart:async';

class ARHazardScreen extends StatefulWidget {
  const ARHazardScreen({super.key});

  @override
  State<ARHazardScreen> createState() => _ARHazardScreenState();
}

class _ARHazardScreenState extends State<ARHazardScreen> with TickerProviderStateMixin {
  // === COLORS ===
  final Color _limeGreen = const Color(0xFFDAF561);
  final Color _periwinkle = const Color(0xFF9FADF4);
  final Color _deepPlum = const Color(0xFF5E213E);
  final Color _coral = const Color(0xFFFFA589);
  final Color _darkNavy = const Color(0xFF07303E);
  final Color _royalBlue = const Color(0xFF3451A3);

  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  
  // State
  List<Map<String, dynamic>> _nearbyHazards = [];
  Position? _currentPosition;
  bool _isLoading = true;
  bool _cameraReady = false;
  bool _showHazardList = true;
  int _hazardsInView = 0;
  
  // Animations
  late AnimationController _pulseController;
  late AnimationController _scanController;
  Timer? _updateTimer;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _initialize();
  }

  Future<void> _initialize() async {
    await _requestPermissions();
    await _initializeCamera();
    await _getCurrentLocation();
    await _loadNearbyHazards();
    _startPeriodicUpdates();
    setState(() => _isLoading = false);
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.location.request();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras!.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        
        await _cameraController!.initialize();
        setState(() => _cameraReady = true);
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _currentPosition = position);
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _loadNearbyHazards() async {
    if (_currentPosition == null) return;

    try {
      final snapshot = await _firestore
          .collection('hazards')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      List<Map<String, dynamic>> nearby = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final hazardLat = data['latitude'] as double?;
        final hazardLon = data['longitude'] as double?;
        
        if (hazardLat != null && hazardLon != null) {
          final distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            hazardLat,
            hazardLon,
          );
          
          if (distance < 1000) {
            nearby.add({
              'id': doc.id,
              'type': data['type'] ?? 'Unknown',
              'distance': distance,
              'latitude': hazardLat,
              'longitude': hazardLon,
              'severity': data['severity'] ?? 'medium',
            });
          }
        }
      }

      nearby.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      
      setState(() {
        _nearbyHazards = nearby.take(10).toList();
        _hazardsInView = nearby.where((h) => (h['distance'] as double) < 100).length;
      });
    } catch (e) {
      debugPrint('Firestore Error: $e');
    }
  }

  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _loadNearbyHazards();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _updateTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AR Hazard View', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _darkNavy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showHazardList ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() => _showHazardList = !_showHazardList);
            },
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _buildARView(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _limeGreen, strokeWidth: 3),
          const SizedBox(height: 24),
          Text(
            'Initializing AR Camera...',
            style: TextStyle(color: _limeGreen, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildARView() {
    return Stack(
      children: [
        // Live Camera Feed
        if (_cameraReady && _cameraController != null)
          SizedBox.expand(
            child: CameraPreview(_cameraController!),
          )
        else
          Container(
            color: Colors.black,
            child: Center(
              child: Text(
                'Camera Unavailable',
                style: TextStyle(color: _limeGreen, fontSize: 18),
              ),
            ),
          ),

        // AR Overlay - Top Status Bar
        SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _limeGreen.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: _limeGreen.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _limeGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _limeGreen.withOpacity(_pulseController.value),
                                blurRadius: 10,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AR SCANNING',
                      style: TextStyle(
                        color: _limeGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _coral.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _coral),
                      ),
                      child: Text(
                        '${_nearbyHazards.length}',
                        style: TextStyle(
                          color: _coral,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatChip(Icons.warning, '${_nearbyHazards.length}', 'Nearby'),
                    _buildStatChip(Icons.visibility, '$_hazardsInView', 'In Range'),
                    _buildStatChip(Icons.camera_alt, 'LIVE', 'Camera'),
                  ],
                ),
              ],
            ),
          ),
        ),

        // AR Markers Overlay (Simulated 3D positions)
        if (_nearbyHazards.isNotEmpty)
          ..._nearbyHazards.asMap().entries.take(5).map((entry) {
            final index = entry.key;
            final hazard = entry.value;
            return _buildARMarker(hazard, index);
          }),

        // Center Crosshair with Scanning Animation
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Scanning ring
              AnimatedBuilder(
                animation: _scanController,
                builder: (context, child) {
                  return Container(
                    width: 200 + (50 * _scanController.value),
                    height: 200 + (50 * _scanController.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _periwinkle.withOpacity(0.5 * (1 - _scanController.value)),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
              // Crosshair
              Icon(
                Icons.center_focus_strong,
                size: 80,
                color: _periwinkle.withOpacity(0.7),
              ),
            ],
          ),
        ),

        // Bottom Hazard List
        if (_showHazardList && _nearbyHazards.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.95),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: _royalBlue, width: 2)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.radar, color: _limeGreen, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Detected Hazards',
                          style: TextStyle(
                            color: _limeGreen,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: _coral,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _nearbyHazards.length,
                      itemBuilder: (context, index) {
                        final hazard = _nearbyHazards[index];
                        return _buildHazardItem(hazard, index);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _darkNavy.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _periwinkle.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _periwinkle, size: 16),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  color: _periwinkle,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildARMarker(Map<String, dynamic> hazard, int index) {
    final distance = hazard['distance'] as double;
    final type = hazard['type'] as String;
    
    // Simulate AR placement based on distance
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Position based on index (spread across screen)
    final left = (screenWidth * 0.2) + (index * screenWidth * 0.15);
    final top = screenHeight * 0.3 + (index % 2 == 0 ? 0 : 80);

    return Positioned(
      top: top,
      left: left,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (0.1 * _pulseController.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _deepPlum.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _coral, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: _coral.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: _coral, size: 18),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        type.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${distance.toStringAsFixed(0)}m',
                        style: TextStyle(
                          color: _limeGreen,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHazardItem(Map<String, dynamic> hazard, int index) {
    final type = hazard['type'] as String;
    final distance = hazard['distance'] as double;
    final severity = hazard['severity'] as String;

    Color severityColor = _coral;
    if (severity == 'high') severityColor = const Color(0xFFFF6B6B);
    if (severity == 'low') severityColor = _limeGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: severityColor.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: severityColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.warning_amber, color: severityColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${distance.toStringAsFixed(0)}m ahead',
                  style: TextStyle(color: severityColor, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _royalBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#${index + 1}',
              style: TextStyle(
                color: _royalBlue,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}