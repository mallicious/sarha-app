import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResponderDashboardScreen extends StatefulWidget {
  const ResponderDashboardScreen({super.key});

  @override
  State<ResponderDashboardScreen> createState() => _ResponderDashboardScreenState();
}

class _ResponderDashboardScreenState extends State<ResponderDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String _filterStatus = 'all'; // all, pending, fixed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // BACKGROUND: Periwinkle Blue from palette
      backgroundColor: const Color(0xFF9FADF4),
      appBar: AppBar(
        title: const Text(
          'Responder Dashboard', 
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)
        ),
        // APPBAR: Teal from palette
        backgroundColor: const Color(0xFF217C82),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('responders').doc(_auth.currentUser?.uid).get(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final isAdmin = data?['isAdmin'] ?? false;
                
                if (isAdmin) {
                  return IconButton(
                    icon: const Icon(Icons.admin_panel_settings),
                    tooltip: 'Admin Panel',
                    onPressed: () => Navigator.pushNamed(context, '/adminPanel'),
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsSection(),
          _buildFilterSection(),
          Expanded(
            child: _buildHazardList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('hazards').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: Color(0xFF217C82))));
        }

        final hazards = snapshot.data?.docs ?? [];
        final totalHazards = hazards.length;
        final pendingHazards = hazards.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['status'] ?? 'pending') != 'fixed';
        }).length;
        final fixedHazards = totalHazards - pendingHazards;

        return Container(
          padding: const EdgeInsets.all(20),
          // BACKGROUND: Lime from palette
          color: const Color(0xFFDAF561),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.assignment,
                  title: 'Total',
                  value: totalHazards.toString(),
                  color: const Color(0xFF073D3E), // Dark Green Text
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.pending_actions,
                  title: 'Pending',
                  value: pendingHazards.toString(),
                  color: const Color(0xFF5E213E), // Deep Plum Text
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.task_alt,
                  title: 'Fixed',
                  value: fixedHazards.toString(),
                  color: const Color(0xFF217C82), // Teal Text
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({required IconData icon, required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white.withOpacity(0.9),
      child: Row(
        children: [
          const Text('Filter:', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF073D3E))),
          const SizedBox(width: 15),
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Pending', 'pending'),
          const SizedBox(width: 8),
          _buildFilterChip('Fixed', 'fixed'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => setState(() => _filterStatus = value),
      // SELECTED: Peach from palette
      selectedColor: const Color(0xFFFFB589),
      backgroundColor: Colors.grey[200],
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF5E213E) : Colors.black87,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildHazardList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('hazards').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var hazards = snapshot.data!.docs;
        if (_filterStatus != 'all') {
          hazards = hazards.where((doc) => (doc.data() as Map)['status'] == _filterStatus).toList();
        }

        if (hazards.isEmpty) {
          return const Center(child: Text("No reports found", style: TextStyle(fontWeight: FontWeight.bold)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: hazards.length,
          itemBuilder: (context, index) {
            final doc = hazards[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildHazardCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildHazardCard(String hazardId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    final isFixed = status == 'fixed';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: const Color(0xFF217C82).withOpacity(0.3)),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFDAF561),
                  child: Icon(_getHazardIcon(data['type']), color: const Color(0xFF217C82)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (data['type'] ?? 'Hazard').toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF073D3E)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFixed ? Colors.green[100] : const Color(0xFFFFB589).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: isFixed ? Colors.green[800] : const Color(0xFF5E213E),
                      fontWeight: FontWeight.bold, fontSize: 10
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            Text(data['description'] ?? 'No description provided', style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 15),
            Row(
              children: [
                if (!isFixed)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsFixed(hazardId),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Resolve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF217C82),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                if (!isFixed) const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {}, // Open Map Logic
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Map View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF217C82),
                      side: const BorderSide(color: Color(0xFF217C82)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsFixed(String hazardId) async {
    try {
      await _firestore.collection('hazards').doc(hazardId).update({
        'status': 'fixed',
        'fixedAt': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Hazard Resolved!', Colors.green);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  IconData _getHazardIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'pothole': return Icons.circle;
      case 'flooding': return Icons.water_drop;
      case 'roadwork': return Icons.construction;
      default: return Icons.warning_amber_rounded;
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }
}