import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import 'pick_location_screen.dart';

class ManualReportScreen extends StatefulWidget {
  const ManualReportScreen({super.key});

  @override
  State<ManualReportScreen> createState() => _ManualReportScreenState();
}

class _ManualReportScreenState extends State<ManualReportScreen> {
  static const Color primaryPurple = Color(0xFF9E9EF8);
  static const Color accentOrange = Color(0xFFFF8566);
  static const Color lightGrey = Color(0xFFF5F6FA);

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedHazard = 'Pothole';
  File? _image;
  bool _isLocating = false;

  final List<Map<String, dynamic>> _hazardTypes = [
    {'name': 'Pothole', 'icon': Icons.circle_outlined, 'color': Colors.redAccent},
    {'name': 'Flooding', 'icon': Icons.tsunami, 'color': Colors.blueAccent},
    {'name': 'Bumpy Road', 'icon': Icons.waves, 'color': Colors.orangeAccent},
    {'name': 'Broken Light', 'icon': Icons.lightbulb_outline, 'color': Colors.yellowAccent},
    {'name': 'Road Debris', 'icon': Icons.recycling, 'color': Colors.greenAccent},
    {'name': 'Construction', 'icon': Icons.construction, 'color': Colors.brown},
  ];

  @override
  void initState() {
    super.initState();
    _autoLocate();
  }

  Future<void> _autoLocate() async {
    setState(() => _isLocating = true);
    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        setState(() => _locationController.text = "${marks.first.street}, ${marks.first.locality}, Abuja");
      }
    } catch (e) {
      debugPrint("Location error: $e");
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _searchAndConfirm() async {
    if (_locationController.text.isEmpty) return;
    setState(() => _isLocating = true);
    try {
      // Validates if the address is real
      await locationFromAddress("${_locationController.text}, Abuja");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location confirmed!'), backgroundColor: primaryPurple),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not found. Please refine.'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New Report', style: TextStyle(color: Color.fromARGB(255, 237, 236, 236), fontWeight: FontWeight.bold)),
        backgroundColor: primaryPurple, elevation: 0, centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section("Hazard Location"),
            _buildLocationInput(),
            const SizedBox(height: 24),
            _section("Hazard Type"),
            _buildGrid(),
            const SizedBox(height: 24),
            _section("Description"),
            _buildDescField(),
            const SizedBox(height: 24),
            _section("Photo Evidence"),
            _buildPicker(),
            const SizedBox(height: 32),
            _buildSubmit(),
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)));

  Widget _buildLocationInput() => Container(
    decoration: BoxDecoration(color: lightGrey, borderRadius: BorderRadius.circular(16)),
    child: TextField(
      controller: _locationController,
      onSubmitted: (_) => _searchAndConfirm(),
      decoration: InputDecoration(
        hintText: "Type address...",
        prefixIcon: const Icon(Icons.search, color: primaryPurple),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLocating)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryPurple))),
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: _searchAndConfirm,
              tooltip: 'Confirm location',
            ),
            IconButton(
              icon: const Icon(Icons.map_rounded, color: accentOrange),
              onPressed: () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const PickLocationScreen()));
                if (res != null) setState(() => _locationController.text = res['address']);
              },
              tooltip: 'Open map',
            ),
          ],
        ),
        border: InputBorder.none, contentPadding: const EdgeInsets.all(16),
      ),
    ),
  );

  Widget _buildGrid() => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
    itemCount: _hazardTypes.length,
    itemBuilder: (context, i) {
      bool sel = _selectedHazard == _hazardTypes[i]['name'];
      return GestureDetector(
        onTap: () => setState(() => _selectedHazard = _hazardTypes[i]['name']),
        child: Container(
          decoration: BoxDecoration(
            color: sel ? primaryPurple : Colors.white, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? primaryPurple : lightGrey, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_hazardTypes[i]['icon'], color: sel ? Colors.white : _hazardTypes[i]['color'], size: 28),
              Text(_hazardTypes[i]['name'], style: TextStyle(color: sel ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildDescField() => TextField(
    controller: _descriptionController, maxLines: 3,
    decoration: InputDecoration(hintText: "What's the issue?", filled: true, fillColor: const Color.fromARGB(255, 5, 7, 17), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
  );

  Widget _buildPicker() => GestureDetector(
    onTap: () async {
      final p = await ImagePicker().pickImage(source: ImageSource.camera);
      if (p != null) setState(() => _image = File(p.path));
    },
    child: Container(
      height: 120, width: double.infinity, decoration: BoxDecoration(color: lightGrey, borderRadius: BorderRadius.circular(16)),
      child: _image == null ? const Icon(Icons.add_a_photo, color: primaryPurple, size: 40) : ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_image!, fit: BoxFit.cover)),
    ),
  );

  Widget _buildSubmit() => SizedBox(
    width: double.infinity, height: 60,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: accentOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      onPressed: () {
        if (_locationController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a location')));
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report Sent!'), backgroundColor: primaryPurple));
      },
      child: const Text('SUBMIT REPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
  );
}