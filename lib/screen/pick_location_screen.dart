// lib/screen/pick_location_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class PickLocationScreen extends StatefulWidget {
  final LatLng initialLocation;
  const PickLocationScreen({super.key, required this.initialLocation});

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  final Color _limeGreen = const Color(0xFFDAF561);
  final Color _darkNavy = const Color(0xFF07303E);
  final Color _royalBlue = const Color(0xFF3451A3);
  final Color _coral = const Color(0xFFFFA589);

  late LatLng _pickedLocation;
  String _selectedAddress = "Fetching address...";
  MapType _mapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
    _getAddress(_pickedLocation);
  }

  Future<void> _getAddress(LatLng coords) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(coords.latitude, coords.longitude);
      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first;
        setState(() {
          _selectedAddress = "${p.street}, ${p.locality}, ${p.country}";
        });
      }
    } catch (e) {
      setState(() => _selectedAddress = "Unknown location");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        backgroundColor: _darkNavy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () => setState(() => _mapType = _mapType == MapType.normal ? MapType.satellite : MapType.normal),
          )
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _pickedLocation, zoom: 16),
            mapType: _mapType,
            onTap: (pos) {
              setState(() => _pickedLocation = pos);
              _getAddress(pos);
            },
            markers: {
              Marker(
                markerId: const MarkerId('m1'),
                position: _pickedLocation,
                draggable: true,
                onDragEnd: (pos) {
                  setState(() => _pickedLocation = pos);
                  _getAddress(pos);
                },
              ),
            },
          ),
          // Top Info Panel
          Positioned(
            top: 20, left: 15, right: 15,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [const BoxShadow(blurRadius: 10, color: Colors.black12)]),
              child: Text(_selectedAddress, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _limeGreen,
        onPressed: () {
          // Return a MAP so the first screen gets EVERYTHING it needs
          Navigator.pop(context, {
            'address': _selectedAddress,
            'lat': _pickedLocation.latitude,
            'lng': _pickedLocation.longitude,
          });
        },
        label: const Text('CONFIRM THIS LOCATION', style: TextStyle(color: Color(0xFF07303E), fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.check, color: Color(0xFF07303E)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}