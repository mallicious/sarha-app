import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class HazardDetailScreen extends StatefulWidget {
  final String hazardId;
  const HazardDetailScreen({super.key, required this.hazardId});

  @override
  State<HazardDetailScreen> createState() => _HazardDetailScreenState();
}

class _HazardDetailScreenState extends State<HazardDetailScreen> {
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color lightBlue = Color(0xFF5AC8FA);
  static const Color backgroundBlue = Color(0xFFE5F4FF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkBlue = Color(0xFF1C3A5E);
  static const Color gray = Color(0xFF8E8E93);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: const Text('Hazard Details', style: TextStyle(fontWeight: FontWeight.w600, color: white)),
        backgroundColor: primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('hazards').doc(widget.hazardId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: primaryBlue));
          }
          
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text('Hazard not found'));
          }
          
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHazardInfoCard(data),
                _buildMediaSection(data),
                _buildLocationSection(data),
                _buildResponseHistory(),
                _buildActionButtons(data),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHazardInfoCard(Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    final isPending = status == 'pending';
    
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPending 
                      ? Colors.orange.withOpacity(0.2) 
                      : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getHazardIcon(data['type']),
                    color: isPending ? Colors.orange : Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (data['type'] ?? 'Hazard').toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: darkBlue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPending ? 'PENDING' : 'RESOLVED',
                    style: const TextStyle(
                      color: white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              data['description'] ?? 'No description provided',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: darkBlue.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: gray),
                const SizedBox(width: 8),
                Text(
                  'Reported ${_formatTimestamp(data['timestamp'])}',
                  style: const TextStyle(color: gray, fontSize: 13),
                ),
              ],
            ),
            if (!isPending && data['fixedAt'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Resolved ${_formatTimestamp(data['fixedAt'])}',
                    style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(Map<String, dynamic> data) {
    final hasImage = data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty;
    if (!hasImage) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Photo Evidence',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: data['imageUrl'],
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: backgroundBlue,
                  child: const Center(child: CircularProgressIndicator(color: primaryBlue)),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: backgroundBlue,
                  child: const Center(child: Icon(Icons.broken_image_rounded, size: 40, color: gray)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(Map<String, dynamic> data) {
    final address = data['address'] as String?;
    final lat = data['latitude'];
    final lng = data['longitude'];
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 12),
            if (address != null && address.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_rounded, size: 20, color: primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        fontSize: 14,
                        color: darkBlue.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (lat != null && lng != null)
              Row(
                children: [
                  const Icon(Icons.location_pin, size: 18, color: gray),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}',
                      style: const TextStyle(color: gray, fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseHistory() {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Response History',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('hazards')
                  .doc(widget.hazardId)
                  .collection('responses')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text(
                    'No responses yet.',
                    style: TextStyle(color: gray.withOpacity(0.7)),
                  );
                }
                
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final response = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.comment, color: primaryBlue, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                response['text'] ?? '',
                                style: const TextStyle(
                                  color: darkBlue,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(response['timestamp']),
                                style: TextStyle(
                                  color: gray,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> data) {
    final isFixed = (data['status'] ?? 'pending') == 'fixed';
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showAddResponseDialog(),
              icon: const Icon(Icons.comment, color: white),
              label: const Text('Add Response'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (!isFixed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _markAsFixed(),
                icon: const Icon(Icons.check_circle, color: white),
                label: const Text('Mark Resolved'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddResponseDialog() {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Response'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter your response...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              
              await _firestore
                  .collection('hazards')
                  .doc(widget.hazardId)
                  .collection('responses')
                  .add({
                'text': controller.text.trim(),
                'timestamp': FieldValue.serverTimestamp(),
                'responderId': _auth.currentUser?.uid,
              });
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Response added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsFixed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Resolved?'),
        content: const Text('This will mark the hazard as resolved. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('hazards').doc(widget.hazardId).update({
        'status': 'fixed',
        'fixedAt': FieldValue.serverTimestamp(),
        'fixedBy': _auth.currentUser?.uid,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Hazard marked as resolved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getHazardIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'pothole':
        return Icons.circle;
      case 'flooding':
        return Icons.water_drop_rounded;
      case 'roadwork':
        return Icons.construction_rounded;
      case 'debris':
        return Icons.delete_outline_rounded;
      case 'street light':
        return Icons.lightbulb_outline_rounded;
      case 'speed bump':
        return Icons.speed_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'just now';
    
    try {
      final DateTime dateTime = (timestamp as Timestamp).toDate();
      final Duration difference = DateTime.now().difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${(difference.inDays / 7).floor()}w ago';
      }
    } catch (e) {
      return 'recently';
    }
  }
}