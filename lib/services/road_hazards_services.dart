import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class RoadHazardService {
  static final RoadHazardService _instance = RoadHazardService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory RoadHazardService() => _instance;

  RoadHazardService._internal();

  // Fetch hazards from Firebase within a certain radius
  Future<List<Map<String, dynamic>>> getNearbyHazards({
    required double latitude,
    required double longitude,
    required double radiusInMeters,
  }) async {
    try {
      final snapshot = await _firestore.collection('road_hazards').get();

      final nearbyHazards =
          snapshot.docs.map((doc) => doc.data()).where((hazard) {
        final distance = _calculateDistance(
          latitude,
          longitude,
          hazard['latitude'] as double,
          hazard['longitude'] as double,
        );
        return distance <= radiusInMeters;
      }).toList();

      return nearbyHazards;
    } catch (e) {
      print('Error fetching hazards: $e');
      return [];
    }
  }

  // Report a new hazard
  Future<bool> reportHazard({
    required String type, // pothole, bump, sinkhole, construction
    required double latitude,
    required double longitude,
    required double severity, // 1-10
    required String description,
    required String reportedBy,
  }) async {
    try {
      await _firestore.collection('road_hazards').add({
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
        'severity': severity,
        'description': description,
        'reportedBy': reportedBy,
        'timestamp': DateTime.now(),
        'verified': false,
      });
      return true;
    } catch (e) {
      print('Error reporting hazard: $e');
      return false;
    }
  }

  // Verify/confirm a hazard (increase trust score)
  Future<bool> confirmHazard(String hazardId) async {
    try {
      await _firestore
          .collection('road_hazards')
          .doc(hazardId)
          .update({'verified': true});
      return true;
    } catch (e) {
      print('Error confirming hazard: $e');
      return false;
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c * 1000; // Convert to meters
  }

  static double _degreesToRadians(double degrees) => degrees * pi / 180;
}
