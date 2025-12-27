// lib/services/ar_service.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ar_hazards.dart';

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
      // 1. Check Camera/AR Permissions (Placeholder for AR-specific checks)
      await _checkARPermissions();

      // 2. Fetch Near Hazards (Using Firestore and Geolocator)
      await _fetchNearbyHazards();
      
      // If all checks pass, set status to ready
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
    // We only rely on Geolocator permission for now
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied.");
    }

    // Simulate other AR setup time
    await Future.delayed(const Duration(seconds: 2));
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
       print("Failed to fetch hazards for AR: $e");
       throw Exception("Failed to fetch hazard data.");
    }
  }
}