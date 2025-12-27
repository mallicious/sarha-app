import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

import 'map_detectionscreen.dart';
import 'manual_reportscreen.dart';
import 'AR_hazardscreen.dart';
import 'settings_screen.dart';
import 'user_type_selection_screen.dart'; // Redirect back here on logout

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LatLng? _location;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      const address = "Abuja, Nigeria";
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        setState(() {
          _location = LatLng(locations.first.latitude, locations.first.longitude);
        });
      }
    } catch (e) {
      debugPrint("Geocoding Error: $e");
      setState(() {
        _location = const LatLng(9.0765, 7.3986); 
      });
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const MapDetectionScreen()));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ManualReportScreen()));
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ARHazardScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.email?.split('@').first ?? "SARHA User";

    return Scaffold(
      backgroundColor: const Color(0xFF9FADF4), 
      appBar: AppBar(
        title: const Text(
          'SARHA', 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)
        ),
        backgroundColor: const Color(0xFF217C82), 
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                // Clear stack and go back to user selection
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const UserTypeSelectionScreen()),
                  (route) => false,
                );
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $name',
                style: const TextStyle(
                  fontSize: 30, 
                  fontWeight: FontWeight.w900, 
                  color: Color(0xFF073D3E),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Drive safe. Detect hazards early.',
                style: TextStyle(
                  color: Color(0xFF5E213E), 
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              _statsCard(),
              const SizedBox(height: 35),
              const Text(
                'Abuja Hazards Map',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w800, 
                  color: Color(0xFF073D3E)
                ),
              ),
              const SizedBox(height: 12),
              _mapPreview(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFFB589), 
        unselectedItemColor: const Color(0xFF217C82), 
        backgroundColor: const Color(0xFFDAF561), 
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Detect'),
          BottomNavigationBarItem(icon: Icon(Icons.add_location), label: 'Report'),
          BottomNavigationBarItem(icon: Icon(Icons.view_in_ar), label: 'AR'),
        ],
      ),
    );
  }

  Widget _statsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9DAD6).withOpacity(0.8), 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF217C82), width: 1.5),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Stat(icon: Icons.warning, label: 'Hazards', value: '450'),
          _Stat(icon: Icons.person, label: 'Reported', value: '12'),
          _Stat(icon: Icons.route, label: 'Distance', value: '85 km'),
        ],
      ),
    );
  }

  Widget _mapPreview() {
    if (_location == null) {
      return const SizedBox(
        height: 220, 
        child: Center(child: CircularProgressIndicator(color: Color(0xFF217C82)))
      );
    }
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF217C82), width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: _location!, zoom: 12),
          myLocationEnabled: true,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Stat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFFB589), size: 30), 
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF073D3E))),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5E213E))),
      ],
    );
  }
}