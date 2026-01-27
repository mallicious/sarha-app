import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'hazard_detailscreen.dart';

class ResponderAllReportsScreen extends StatefulWidget {
  const ResponderAllReportsScreen({super.key});

  @override
  State<ResponderAllReportsScreen> createState() => _ResponderAllReportsScreenState();
}

class _ResponderAllReportsScreenState extends State<ResponderAllReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color backgroundBlue = Color(0xFFE5F4FF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkBlue = Color(0xFF1C3A5E);

  String _selectedFilter = 'all'; // all, pending, fixed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: const Text('All Reports', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: primaryBlue,
        foregroundColor: white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildReportsList()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: white,
      child: Row(
        children: [
          _buildFilterChip('All', 'all', primaryBlue),
          const SizedBox(width: 8),
          _buildFilterChip('Pending', 'pending', Colors.orange),
          const SizedBox(width: 8),
          _buildFilterChip('Resolved', 'fixed', Colors.green),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color,
            width: isSelected ? 0 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? white : color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    Query query = _firestore.collection('hazards').orderBy('timestamp', descending: true);
    
    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryBlue));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildReportCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildReportCard(String hazardId, Map<String, dynamic> data) {
    final hasImage = data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty;
    final status = data['status'] ?? 'pending';
    final isPending = status == 'pending';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HazardDetailScreen(hazardId: hazardId),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending 
              ? Colors.orange.withOpacity(0.3) 
              : Colors.green.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: CachedNetworkImage(
                      imageUrl: data['imageUrl'],
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 160,
                        color: backgroundBlue,
                        child: const Center(child: CircularProgressIndicator(color: primaryBlue)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 160,
                        color: backgroundBlue,
                        child: const Center(
                          child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPending ? Colors.orange : Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPending ? Icons.pending_actions : Icons.check_circle,
                            size: 16,
                            color: white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPending ? 'PENDING' : 'RESOLVED',
                            style: const TextStyle(
                              color: white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isPending 
                            ? Colors.orange.withOpacity(0.2) 
                            : Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getHazardIcon(data['type']),
                          color: isPending ? Colors.orange[700] : Colors.green[700],
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (data['type'] ?? 'Hazard').toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: darkBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 12, color: darkBlue.withOpacity(0.5)),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTimestamp(data['timestamp']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: darkBlue.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data['description'] ?? 'No description provided',
                    style: TextStyle(
                      color: darkBlue.withOpacity(0.7),
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data['address'] != null && (data['address'] as String).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 14, color: darkBlue.withOpacity(0.5)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            data['address'],
                            style: TextStyle(
                              fontSize: 12,
                              color: darkBlue.withOpacity(0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No reports found';
    if (_selectedFilter == 'pending') {
      message = 'No pending reports';
    } else if (_selectedFilter == 'fixed') {
      message = 'No resolved reports yet';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 80, color: darkBlue.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: darkBlue.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
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
    if (timestamp == null) return 'recently';
    
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
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()}w ago';
      } else {
        return '${(difference.inDays / 30).floor()}mo ago';
      }
    } catch (e) {
      return 'recently';
    }
  }
}