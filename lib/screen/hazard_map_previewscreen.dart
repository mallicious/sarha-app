import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class HazardMapPreviewScreen extends StatefulWidget {
  final String hazardId;
  final String hazardType;
  final double latitude;
  final double longitude;
  final String description;

  const HazardMapPreviewScreen({
    super.key,
    required this.hazardId,
    required this.hazardType,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  @override
  State<HazardMapPreviewScreen> createState() => _HazardMapPreviewScreenState();
}

class _HazardMapPreviewScreenState extends State<HazardMapPreviewScreen> {
  // === CALM COLOR PALETTE ===
  static const Color softLavender = Color(0xFFA7B5F4);
  static const Color coral = Color(0xFFFF9B85);
  static const Color cream = Color(0xFFFAF8F5);
  static const Color deepPurple = Color(0xFF4A4063);
  static const Color lightPurple = Color(0xFFD1D5F7);

  GoogleMapController? _mapController;
  late Set<Marker> _markers;

  @override
  void initState() {
    super.initState();
    _initializeMarker();
  }

  void _initializeMarker() {
    _markers = {
      Marker(
        markerId: MarkerId(widget.hazardId),
        position: LatLng(widget.latitude, widget.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerColor()),
        infoWindow: InfoWindow(
          title: widget.hazardType,
          snippet: widget.description,
        ),
      ),
    };
  }

  double _getMarkerColor() {
    switch (widget.hazardType.toLowerCase()) {
      case 'pothole':
        return BitmapDescriptor.hueRed;
      case 'flooding':
        return BitmapDescriptor.hueBlue;
      case 'roadwork':
        return BitmapDescriptor.hueOrange;
      case 'debris':
        return BitmapDescriptor.hueYellow;
      case 'speed bump':
        return BitmapDescriptor.hueViolet;
      default:
        return BitmapDescriptor.hueRose;
    }
  }

  Future<void> _openInGoogleMaps() async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not open Google Maps', coral);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', coral);
    }
  }

  Future<void> _getDirections() async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.latitude},${widget.longitude}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not open directions', coral);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', coral);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
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
        title: Text(
          '${widget.hazardType} Location',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: softLavender,
        foregroundColor: deepPurple,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Hazard Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [softLavender, lightPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getHazardIcon(),
                        color: deepPurple,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.hazardType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: deepPurple,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: deepPurple.withOpacity(0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: coral, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: deepPurple,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.latitude, widget.longitude),
                zoom: 16,
              ),
              markers: _markers,
              onMapCreated: (controller) => _mapController = controller,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _getDirections,
                        icon: const Icon(Icons.directions_rounded, size: 22),
                        label: const Text(
                          'Get Directions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: coral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openInGoogleMaps,
                        icon: const Icon(Icons.open_in_new_rounded, size: 22),
                        label: const Text(
                          'Open Maps',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: softLavender,
                          side: BorderSide(color: softLavender, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getHazardIcon() {
    switch (widget.hazardType.toLowerCase()) {
      case 'pothole':
        return Icons.circle;
      case 'flooding':
        return Icons.water_drop_rounded;
      case 'roadwork':
        return Icons.construction_rounded;
      case 'debris':
        return Icons.delete_outline_rounded;
      case 'speed bump':
        return Icons.speed_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }
}