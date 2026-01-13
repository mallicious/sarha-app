import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HazardHeatmapScreen extends StatefulWidget {
  const HazardHeatmapScreen({super.key});

  @override
  State<HazardHeatmapScreen> createState() => _HazardHeatmapScreenState();
}

class _HazardHeatmapScreenState extends State<HazardHeatmapScreen> {
  GoogleMapController? _mapController;
  Set<Circle> _heatCircles = {};
  final Map<String, int> _hazardCounts = {};

  static const Color softLavender = Color(0xFFA7B5F4);
  static const Color coral = Color(0xFFFF9B85);
  static const Color cream = Color(0xFFFAF8F5);
  static const Color deepPurple = Color(0xFF4A4063);

  @override
  void initState() {
    super.initState();
    _loadHeatmapData();
  }

  Future<void> _loadHeatmapData() async {
    try {
      final hazards = await FirebaseFirestore.instance
          .collection('hazards')
          .where('status', isEqualTo: 'pending')
          .get();

      // Group hazards by location (within 100m radius)
      Map<String, List<DocumentSnapshot>> groupedHazards = {};
      
      for (final hazard in hazards.docs) {
        final data = hazard.data();
        final lat = data['latitude'] ?? 0.0;
        final lng = data['longitude'] ?? 0.0;
        
        // Round to create location groups
        final key = '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
        groupedHazards.putIfAbsent(key, () => []).add(hazard);
      }

      // Create heat circles
      Set<Circle> circles = {};
      
      groupedHazards.forEach((key, hazards) {
        final coords = key.split(',');
        final lat = double.parse(coords[0]);
        final lng = double.parse(coords[1]);
        final count = hazards.length;

        circles.add(
          Circle(
            circleId: CircleId(key),
            center: LatLng(lat, lng),
            radius: _getRadius(count),
            fillColor: _getHeatColor(count).withOpacity(0.3),
            strokeColor: _getHeatColor(count),
            strokeWidth: 2,
          ),
        );

        _hazardCounts[key] = count;
      });

      setState(() => _heatCircles = circles);
    } catch (e) {
      print('❌ Heatmap error: $e');
    }
  }

  // Get circle radius based on hazard count
  double _getRadius(int count) {
    if (count >= 10) return 500.0;
    if (count >= 5) return 300.0;
    return 150.0;
  }

  // Get color based on hazard density
  Color _getHeatColor(int count) {
    if (count >= 10) return Colors.red;
    if (count >= 5) return Colors.orange;
    if (count >= 3) return Colors.yellow[700]!;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text(
          'Hazard Heatmap',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: softLavender,
        foregroundColor: deepPurple,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Legend
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('Low Risk', Colors.green, '1-2'),
                _buildLegendItem('Medium', Colors.yellow[700]!, '3-4'),
                _buildLegendItem('High', Colors.orange, '5-9'),
                _buildLegendItem('Critical', Colors.red, '10+'),
              ],
            ),
          ),
          
          // Map
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(9.0765, 7.3986), // Abuja
                zoom: 12,
              ),
              circles: _heatCircles,
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadHeatmapData,
        backgroundColor: coral,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh'),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String range) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        Text(
          range,
          style: TextStyle(fontSize: 9, color: Colors.grey[600]),
        ),
      ],
    );
  }
}