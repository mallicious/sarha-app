import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Get high-accuracy location
  Future<Position?> getAccurateLocation() async {
    try {
      // Check permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          print('❌ Location permission denied');
          return null;
        }
      }

      // Get location with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      print('📍 Location: ${position.latitude}, ${position.longitude}');
      print('📏 Accuracy: ${position.accuracy}m');

      // Validate accuracy (reject if > 50m)
      if (position.accuracy > 50) {
        print('⚠️ Low accuracy (${position.accuracy}m), retrying...');
        return await _retryWithBestAccuracy();
      }

      return position;
    } catch (e) {
      print('❌ Location error: $e');
      return null;
    }
  }

  // Retry for best accuracy
  Future<Position?> _retryWithBestAccuracy() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      print('❌ Retry failed: $e');
      return null;
    }
  }

  // Check if location is valid (not 0,0 or null island)
  bool isValidLocation(double lat, double lng) {
    // Check if coordinates are not 0,0 (Null Island)
    if (lat == 0.0 && lng == 0.0) {
      print('❌ Invalid: Null Island detected');
      return false;
    }

    // Check if within valid ranges
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      print('❌ Invalid: Out of bounds');
      return false;
    }

    return true;
  }

  // Get location with validation
  Future<Map<String, double>?> getValidatedLocation() async {
    final position = await getAccurateLocation();
    
    if (position == null) return null;
    
    if (!isValidLocation(position.latitude, position.longitude)) {
      return null;
    }

    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
    };
  }

  // Stream location updates (for live tracking)
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }
}
