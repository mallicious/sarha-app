import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'hazard_map_previewscreen.dart';

class ResponderDashboardScreen extends StatefulWidget {
  const ResponderDashboardScreen({super.key});

  @override
  State<ResponderDashboardScreen> createState() => _ResponderDashboardScreenState();
}

class _ResponderDashboardScreenState extends State<ResponderDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String _filterStatus = 'all'; // all, pending, fixed

  // NEW CALM COLOR PALETTE
  static const Color softLavender = Color(0xFFA7B5F4);
  static const Color coral = Color(0xFFFF9B85);
  static const Color cream = Color(0xFFFAF8F5);
  static const Color deepPurple = Color(0xFF4A4063);
  static const Color lightPurple = Color(0xFFD1D5F7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text(
          'Responder Dashboard', 
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5)
        ),
        backgroundColor: softLavender,
        foregroundColor: deepPurple,
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
            icon: const Icon(Icons.logout_rounded),
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
          return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: coral)));
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [softLavender, lightPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.assignment_rounded,
                  title: 'Total Reports',
                  value: totalHazards.toString(),
                  color: deepPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.pending_actions_rounded,
                  title: 'Pending',
                  value: pendingHazards.toString(),
                  color: coral,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle_rounded,
                  title: 'Resolved',
                  value: fixedHazards.toString(),
                  color: Colors.green[700]!,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value, 
            style: TextStyle(
              fontSize: 28, 
              fontWeight: FontWeight.bold, 
              color: color
            )
          ),
          const SizedBox(height: 4),
          Text(
            title, 
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11, 
              fontWeight: FontWeight.w500, 
              color: deepPurple.withOpacity(0.7)
            )
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            'Filter:', 
            style: TextStyle(
              fontWeight: FontWeight.w600, 
              color: deepPurple,
              fontSize: 15
            )
          ),
          const SizedBox(width: 15),
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Pending', 'pending'),
          const SizedBox(width: 8),
          _buildFilterChip('Resolved', 'fixed'),
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
      selectedColor: coral,
      backgroundColor: cream,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : deepPurple,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildHazardList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('hazards').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: coral)
          );
        }

        var hazards = snapshot.data!.docs;
        if (_filterStatus != 'all') {
          hazards = hazards.where((doc) {
            final status = (doc.data() as Map)['status'] ?? 'pending';
            return status == _filterStatus;
          }).toList();
        }

        if (hazards.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded, size: 64, color: deepPurple.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  "No reports found",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: deepPurple.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: softLavender.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getHazardIcon(data['type']), 
                    color: deepPurple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['type'] ?? 'Hazard').toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 15, 
                          color: deepPurple,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(data['timestamp']),
                        style: TextStyle(
                          fontSize: 12,
                          color: deepPurple.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFixed 
                        ? Colors.green[100] 
                        : coral.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isFixed ? 'RESOLVED' : 'PENDING',
                    style: TextStyle(
                      color: isFixed ? Colors.green[800] : coral,
                      fontWeight: FontWeight.bold, 
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              data['description'] ?? 'No description provided',
              style: TextStyle(
                color: deepPurple.withOpacity(0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!isFixed)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsFixed(hazardId),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                      label: const Text('Mark Resolved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: coral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                if (!isFixed) const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // ✅ FIXED: Safe access to prevent null errors + added missing parameters
                      Navigator.push(
                        context, 
                        MaterialPageRoute(
                          builder: (context) => HazardMapPreviewScreen(
                            hazardId: hazardId,  // Added
                            latitude: data['location']?['latitude'] ?? 0.0,  // Safe access
                            longitude: data['location']?['longitude'] ?? 0.0,  // Safe access
                            hazardType: data['type'] ?? 'Hazard',
                            description: data['description'] ?? 'No description provided',  // Added
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map_rounded, size: 20),
                    label: const Text('View on Map'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: deepPurple,
                      side: BorderSide(color: softLavender, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)
                      ),
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    try {
      final DateTime dateTime = (timestamp as Timestamp).toDate();
      final Duration difference = DateTime.now().difference(dateTime);
      
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  Future<void> _markAsFixed(String hazardId) async {
    try {
      await _firestore.collection('hazards').doc(hazardId).update({
        'status': 'fixed',
        'fixedAt': FieldValue.serverTimestamp(),
        'fixedBy': _auth.currentUser?.uid,
      });
      _showSnackBar('Hazard marked as resolved!', Colors.green);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  IconData _getHazardIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'pothole': return Icons.circle;
      case 'flooding': return Icons.water_drop_rounded;
      case 'roadwork': return Icons.construction_rounded;
      case 'debris': return Icons.delete_outline_rounded;
      case 'street light': return Icons.lightbulb_outline_rounded;
      default: return Icons.warning_amber_rounded;
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}