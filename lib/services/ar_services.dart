// lib/services/ar_service.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Ensure this model exists or use a generic Map
class ArHazard {
  final String id;
  final double lat;
  final double lng;
  final String type;

  ArHazard({required this.id, required this.lat, required this.lng, required this.type});

  factory ArHazard.fromFirestore(Map<String, dynamic> data, String id) {
    return ArHazard(
      id: id,
      lat: data['latitude'] ?? 0.0,
      lng: data['longitude'] ?? 0.0,
      type: data['type'] ?? 'Unknown',
    );
  }
}

enum ARStatus { 
  initializing, 
  permissionDenied, 
  cameraReady, 
  error 
}

class ARService extends ChangeNotifier {
  ARStatus _status = ARStatus.initializing;
  List<ArHazard> _nearbyHazards = [];

  ARStatus get status => _status;
  List<ArHazard> get nearbyHazards => _nearbyHazards;

  ARService() {
    initializeAR();
  }

  Future<void> initializeAR() async {
    _status = ARStatus.initializing;
    notifyListeners();

    try {
      await _checkARPermissions();
      await _fetchNearbyHazards();
      _status = ARStatus.cameraReady;
    } catch (e) {
      if (e.toString().contains('denied')) {
        _status = ARStatus.permissionDenied;
      } else {
        _status = ARStatus.error;
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> _checkARPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied.");
    }
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> _fetchNearbyHazards() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('hazards')
          .limit(20) 
          .get();

      _nearbyHazards = snapshot.docs.map((doc) => 
        ArHazard.fromFirestore(doc.data(), doc.id)
      ).toList();
    } catch (e) {
       debugPrint("Failed to fetch hazards for AR: $e");
       throw Exception("Failed to fetch hazard data.");
    }
  }
}
