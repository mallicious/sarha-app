// lib/models/ar_hazard.dart

class ArHazard {
  final String id;
  final String type;
  final double latitude;
  final double longitude;
  final String description;

  ArHazard({
    required this.id,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  // Factory constructor to create a model from a Firestore map
  factory ArHazard.fromFirestore(Map<String, dynamic> data, String id) {
    return ArHazard(
      id: id,
      type: data['type'] as String,
      latitude: data['latitude'] as double,
      longitude: data['longitude'] as double,
      description: data['description'] as String? ?? 'No description',
    );
  }
}