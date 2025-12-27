// lib/screen/manual_reportscreen.dart - SEARCH LOCATION IN GOOGLE MAPS

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

enum HazardType {
  pothole,
  flooding,
  debris,
  roadwork,
  speedBump,
  roughRoad,
  other
}

class ManualReportScreen extends StatefulWidget {
  const ManualReportScreen({super.key});

  @override
  State<ManualReportScreen> createState() => _ManualReportScreenState();
}

class _ManualReportScreenState extends State<ManualReportScreen> {
  // === COLOR PALETTE ===
  final Color _limeGreen = const Color(0xFFDAF561);
  final Color _periwinkle = const Color(0xFF9FADF4);
  final Color _deepPlum = const Color(0xFF5E213E);
  final Color _coral = const Color(0xFFFFA589);
  final Color _darkNavy = const Color(0xFF07303E);
  final Color _royalBlue = const Color(0xFF3451A3);
  final Color _palePink = const Color(0xFFF9DAD6);
  final Color _sand = const Color(0xFFE3D0B3);

  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController(); // NEW: For manual address input

  HazardType? _hazardType;
  double? _latitude;
  double? _longitude;
  String _locationAddress = 'No location selected';
  bool _loading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _descCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ================= SEARCH ADDRESS AND GET COORDINATES =================

  Future<void> _searchAddress() async {
    final address = _addressCtrl.text.trim();

    if (address.isEmpty) {
      _snack('Please enter an address to search', _deepPlum);
      return;
    }

    setState(() => _loading = true);

    try {
      // Convert address to coordinates using Geocoding
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final location = locations.first;

        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
          _locationAddress = address;
        });

        _snack('Location found: $address', _limeGreen);
      } else {
        _snack('Address not found. Try different keywords.', _deepPlum);
      }
    } catch (e) {
      _snack('Could not find location. Try again.', _deepPlum);
      debugPrint('Geocoding error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ================= OPEN GOOGLE MAPS FOR SEARCH =================

  Future<void> _openGoogleMapsSearch() async {
    try {
      // Make search dynamic: Use address field if filled, else default to Abuja
      final searchQuery =
          _addressCtrl.text.isNotEmpty ? _addressCtrl.text : 'Abuja, Nigeria';
      final url =
          'geo:0,0?q=${Uri.encodeComponent(searchQuery)}'; // Use geo: scheme for better app launching
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Prefers Maps app over browser
        );

        // Show instructions only after successful launch
        _showMapInstructionDialog();
      } else {
        // More specific error message
        _snack(
            'Google Maps is not available on this device. Please install it or use a browser.',
            _deepPlum);
      }
    } catch (e) {
      // Log the error for debugging
      debugPrint('Error opening Google Maps: $e');
      _snack('Failed to open Google Maps: ${e.toString()}', _deepPlum);
    }
  }

  void _showMapInstructionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.map, color: _royalBlue),
            const SizedBox(width: 12),
            const Text('Find Location'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Search for the hazard location in Google Maps',
              style: TextStyle(color: _darkNavy, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              '2. Copy the address or coordinates',
              style: TextStyle(color: _darkNavy, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              '3. Come back and paste it in the "Address" field',
              style: TextStyle(color: _darkNavy, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              '4. Tap "Search" button to find coordinates',
              style: TextStyle(color: _darkNavy, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _limeGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _limeGreen),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: _royalBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Example: "16th Avenue, Gwarimpa, Abuja"',
                      style: TextStyle(
                        color: _darkNavy,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _royalBlue,
            ),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  // ================= DETECT CURRENT LOCATION =================

  Future<void> _detectCurrentLocation() async {
    setState(() => _loading = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Please enable location services', _deepPlum);
        setState(() => _loading = false);
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Location permission denied', _deepPlum);
        setState(() => _loading = false);
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String address = 'Unknown location';

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address =
            '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? 'Abuja'}'
                .trim()
                .replaceFirst(',', '')
                .trim();
      }

      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationAddress = address;
        _addressCtrl.text = address;
      });

      _snack('Current location detected!', _limeGreen);
    } catch (e) {
      _snack('Failed to get location: ${e.toString()}', _deepPlum);
    } finally {
      setState(() => _loading = false);
    }
  }

  // ================= SUBMIT =================

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _snack('Please fill in all required fields', _deepPlum);
      return;
    }

    if (_latitude == null || _longitude == null) {
      _snack('Please select or search for a location', _deepPlum);
      return;
    }

    setState(() => _loading = true);

    try {
      await _firestore.collection('hazards').add({
        'type': _hazardType!.name,
        'description': _descCtrl.text.trim(),
        'latitude': _latitude!,
        'longitude': _longitude!,
        'roadName': _locationAddress,
        'userId': _auth.currentUser?.uid ?? 'anonymous',
        'timestamp': FieldValue.serverTimestamp(),
        'reportMethod': 'manual',
        'status': 'pending',
        'severity': 'medium',
      });

      _snack('Hazard reported successfully!', _limeGreen);
      Navigator.pop(context);
    } catch (e) {
      _snack('Submission failed: ${e.toString()}', _deepPlum);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _palePink,
      appBar: AppBar(
        title: const Text(
          'Report Hazard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _darkNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _royalBlue, strokeWidth: 3),
                  const SizedBox(height: 16),
                  Text(
                    'Processing...',
                    style: TextStyle(color: _darkNavy, fontSize: 16),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _hazardDropdown(),
                    const SizedBox(height: 16),
                    _descriptionField(),
                    const SizedBox(height: 24),
                    _locationSection(),
                    const SizedBox(height: 30),
                    _submitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_darkNavy, _royalBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _royalBlue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.report_problem, color: _limeGreen, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manual Hazard Report',
                  style: TextStyle(
                    color: _limeGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Help keep roads safe for everyone',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hazardDropdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<HazardType>(
        decoration: InputDecoration(
          labelText: 'Hazard Type *',
          labelStyle: TextStyle(color: _darkNavy, fontWeight: FontWeight.bold),
          prefixIcon: Icon(Icons.warning_amber, color: _coral),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _periwinkle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _periwinkle.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _royalBlue, width: 2),
          ),
        ),
        items: HazardType.values
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    _formatHazardType(e.name),
                    style: TextStyle(color: _darkNavy),
                  ),
                ))
            .toList(),
        onChanged: (v) => setState(() => _hazardType = v),
        validator: (v) => v == null ? 'Please select hazard type' : null,
      ),
    );
  }

  String _formatHazardType(String type) {
    return type
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .trim()
        .toUpperCase();
  }

  Widget _descriptionField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _descCtrl,
        maxLines: 4,
        style: TextStyle(color: _darkNavy),
        decoration: InputDecoration(
          labelText: 'Description (Optional)',
          labelStyle: TextStyle(color: _darkNavy, fontWeight: FontWeight.bold),
          hintText: 'Provide additional details about the hazard...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.description, color: _periwinkle),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _periwinkle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _periwinkle.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _royalBlue, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _locationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: _coral, size: 24),
              const SizedBox(width: 8),
              Text(
                'Location *',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _darkNavy,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Address Search Field
          TextFormField(
            controller: _addressCtrl,
            style: TextStyle(color: _darkNavy),
            decoration: InputDecoration(
              labelText: 'Search Address',
              hintText: 'e.g., 16th Avenue, Gwarimpa, Abuja',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: Icon(Icons.search, color: _royalBlue),
              suffixIcon: IconButton(
                icon: Icon(Icons.send, color: _limeGreen),
                onPressed: _searchAddress,
                tooltip: 'Search',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _royalBlue, width: 2),
              ),
            ),
            onFieldSubmitted: (_) => _searchAddress(),
          ),

          const SizedBox(height: 16),

          // Current Selection Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _limeGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _limeGreen),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: _limeGreen, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationAddress,
                    style: TextStyle(color: _darkNavy, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Buttons Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _detectCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Current Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _royalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openGoogleMapsSearch,
                  icon: const Icon(Icons.map),
                  label: const Text('Search Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _submitButton() {
    return ElevatedButton(
      onPressed: _loading ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: _limeGreen,
        disabledBackgroundColor: Colors.grey[300],
        foregroundColor: _darkNavy,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
      child: Text(
        _loading ? 'Submitting...' : 'Submit Report',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
