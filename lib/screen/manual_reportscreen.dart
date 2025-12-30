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
  // === CALM COLOR PALETTE ===
  static const Color softLavender = Color(0xFFA7B5F4);
  static const Color coral = Color(0xFFFF9B85);
  static const Color cream = Color(0xFFFAF8F5);
  static const Color deepPurple = Color(0xFF4A4063);
  static const Color lightPurple = Color(0xFFD1D5F7);

  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

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

  Future<void> _searchAddress() async {
    final address = _addressCtrl.text.trim();

    if (address.isEmpty) {
      _snack('Please enter an address to search', coral);
      return;
    }

    setState(() => _loading = true);

    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final location = locations.first;

        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
          _locationAddress = address;
        });

        _snack('Location found: $address', Colors.green);
      } else {
        _snack('Address not found. Try different keywords.', coral);
      }
    } catch (e) {
      _snack('Could not find location. Try again.', coral);
      debugPrint('Geocoding error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openGoogleMapsSearch() async {
    try {
      final searchQuery = _addressCtrl.text.isNotEmpty ? _addressCtrl.text : 'Abuja, Nigeria';
      final url = 'geo:0,0?q=${Uri.encodeComponent(searchQuery)}';
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showMapInstructionDialog();
      } else {
        _snack('Google Maps is not available on this device.', coral);
      }
    } catch (e) {
      debugPrint('Error opening Google Maps: $e');
      _snack('Failed to open Google Maps: ${e.toString()}', coral);
    }
  }

  void _showMapInstructionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.map_rounded, color: softLavender, size: 28),
            const SizedBox(width: 12),
            Text('Find Location', style: TextStyle(color: deepPurple, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInstructionStep('1', 'Search for the hazard location in Google Maps'),
            _buildInstructionStep('2', 'Copy the address or coordinates'),
            _buildInstructionStep('3', 'Come back and paste it in the "Address" field'),
            _buildInstructionStep('4', 'Tap "Search" button to find coordinates'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightPurple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: softLavender),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: coral, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Example: "16th Avenue, Gwarimpa, Abuja"',
                      style: TextStyle(color: deepPurple, fontSize: 12, fontStyle: FontStyle.italic),
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
              backgroundColor: coral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: softLavender,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: deepPurple, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _detectCurrentLocation() async {
    setState(() => _loading = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Please enable location services', coral);
        setState(() => _loading = false);
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _snack('Location permission denied', coral);
        setState(() => _loading = false);
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String address = 'Unknown location';

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address = '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? 'Abuja'}'.trim().replaceFirst(',', '').trim();
      }

      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationAddress = address;
        _addressCtrl.text = address;
      });

      _snack('Current location detected!', Colors.green);
    } catch (e) {
      _snack('Failed to get location: ${e.toString()}', coral);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _snack('Please fill in all required fields', coral);
      return;
    }

    if (_latitude == null || _longitude == null) {
      _snack('Please select or search for a location', coral);
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

      _snack('Hazard reported successfully!', Colors.green);
      Navigator.pop(context);
    } catch (e) {
      _snack('Submission failed: ${e.toString()}', coral);
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
        title: const Text('Report Hazard', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: softLavender,
        foregroundColor: deepPurple,
        elevation: 0,
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: coral, strokeWidth: 3),
                  const SizedBox(height: 16),
                  Text('Processing...', style: TextStyle(color: deepPurple, fontSize: 16)),
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
          colors: [softLavender, lightPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: softLavender.withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.report_problem_rounded, color: coral, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manual Hazard Report', style: TextStyle(color: deepPurple, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Help keep roads safe for everyone', style: TextStyle(color: deepPurple.withOpacity(0.7), fontSize: 13)),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: DropdownButtonFormField<HazardType>(
        decoration: InputDecoration(
          labelText: 'Hazard Type *',
          labelStyle: TextStyle(color: deepPurple, fontWeight: FontWeight.w600),
          prefixIcon: Icon(Icons.warning_amber_rounded, color: coral),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: softLavender.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: softLavender, width: 2),
          ),
        ),
        items: HazardType.values
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(_formatHazardType(e.name), style: TextStyle(color: deepPurple)),
                ))
            .toList(),
        onChanged: (v) => setState(() => _hazardType = v),
        validator: (v) => v == null ? 'Please select hazard type' : null,
      ),
    );
  }

  String _formatHazardType(String type) {
    return type.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}').trim().toUpperCase();
  }

  Widget _descriptionField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextFormField(
        controller: _descCtrl,
        maxLines: 4,
        style: TextStyle(color: deepPurple),
        decoration: InputDecoration(
          labelText: 'Description (Optional)',
          labelStyle: TextStyle(color: deepPurple, fontWeight: FontWeight.w600),
          hintText: 'Provide additional details about the hazard...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.description_rounded, color: softLavender),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: softLavender.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: softLavender, width: 2),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: coral, size: 24),
              const SizedBox(width: 8),
              Text('Location *', style: TextStyle(fontWeight: FontWeight.bold, color: deepPurple, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _addressCtrl,
            style: TextStyle(color: deepPurple),
            decoration: InputDecoration(
              labelText: 'Search Address',
              hintText: 'e.g., 16th Avenue, Gwarimpa, Abuja',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: softLavender),
              suffixIcon: IconButton(
                icon: Icon(Icons.send_rounded, color: coral),
                onPressed: _searchAddress,
                tooltip: 'Search',
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: softLavender, width: 2),
              ),
            ),
            onFieldSubmitted: (_) => _searchAddress(),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_locationAddress, style: TextStyle(color: deepPurple, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _detectCurrentLocation,
                  icon: const Icon(Icons.my_location_rounded, size: 20),
                  label: const Text('Current Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: softLavender,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openGoogleMapsSearch,
                  icon: const Icon(Icons.map_rounded, size: 20),
                  label: const Text('Search Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _submit,
        icon: const Icon(Icons.send_rounded, size: 22),
        label: Text(_loading ? 'Submitting...' : 'Submit Report', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[400],
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }
}