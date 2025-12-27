// lib/screen/admin_panel_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String _selectedFilter = 'pending'; // pending, approved, rejected

  @override
  Widget build(BuildContext context) {
    // Dynamically fetch theme colors
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        // AppBar styling is now handled by your global theme
        actions: [
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
          // Stats Section
          _buildStatsSection(colorScheme),
          
          // Filter Section
          _buildFilterSection(colorScheme),
          
          // Pending Responders List
          Expanded(
            child: _buildRespondersList(colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(ColorScheme colorScheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('responders').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final responders = snapshot.data!.docs;
        final totalResponders = responders.length;
        final pendingResponders = responders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['verificationStatus'] == 'pending';
        }).length;
        final approvedResponders = responders.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['verificationStatus'] == 'approved';
        }).length;

        return Container(
          padding: const EdgeInsets.all(20),
          color: colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.people,
                  title: 'Total',
                  value: totalResponders.toString(),
                  color: colorScheme.primary, // Teal
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.pending,
                  title: 'Pending',
                  value: pendingResponders.toString(),
                  color: colorScheme.tertiary, // Peach/Amber
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle,
                  title: 'Approved',
                  value: approvedResponders.toString(),
                  color: colorScheme.secondary, // Lime
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      color: colorScheme.surface,
      child: Row(
        children: [
          const Text(
            'Filter:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Pending', 'pending', colorScheme.tertiary),
                  const SizedBox(width: 10),
                  _buildFilterChip('Approved', 'approved', colorScheme.secondary),
                  const SizedBox(width: 10),
                  _buildFilterChip('Rejected', 'rejected', colorScheme.error),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _selectedFilter == value;
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: color,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildRespondersList(ColorScheme colorScheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('responders')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: colorScheme.outline),
                const SizedBox(height: 20),
                const Text(
                  'No responders yet',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          );
        }

        var responders = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['verificationStatus'] ?? 'pending';
          return status == _selectedFilter;
        }).toList();

        if (responders.isEmpty) {
          return Center(
            child: Text(
              'No $_selectedFilter responders',
              style: const TextStyle(fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: responders.length,
          itemBuilder: (context, index) {
            final responderDoc = responders[index];
            final responderData = responderDoc.data() as Map<String, dynamic>;
            
            return _buildResponderCard(responderDoc.id, responderData, colorScheme);
          },
        );
      },
    );
  }

  Widget _buildResponderCard(String responderId, Map<String, dynamic> data, ColorScheme colorScheme) {
    final fullName = data['fullName'] ?? 'Unknown';
    final email = data['email'] ?? 'No email';
    final phone = data['phone'] ?? 'No phone';
    final organization = data['organization'] ?? 'No organization';
    final idNumber = data['idNumber'] ?? 'No ID';
    final status = data['verificationStatus'] ?? 'pending';
    
    final timestamp = data['createdAt'] as Timestamp?;
    final timeAgo = timestamp != null
        ? _getTimeAgo(timestamp.toDate())
        : 'Unknown time';

    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'approved':
        statusColor = colorScheme.secondary;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = colorScheme.error;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = colorScheme.tertiary;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      elevation: 0, // Using subtle borders for modern look
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    fullName[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 15),
            const Divider(),
            const SizedBox(height: 10),
            
            _buildInfoRow(Icons.email, 'Email', email, colorScheme),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, 'Phone', phone, colorScheme),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.business, 'Organization', organization, colorScheme),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.badge, 'ID Number', idNumber, colorScheme),
            
            if (status == 'pending') ...[
              const SizedBox(height: 20),
              
              if (data['idCardUrl'] != null && data['idCardUrl'].toString().isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _viewIdCard(context, data['idCardUrl']),
                    icon: const Icon(Icons.image, size: 18),
                    label: const Text('View ID Card'),
                  ),
                ),
              
              const SizedBox(height: 10),
              
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _approveResponder(responderId, colorScheme),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.secondary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectResponder(responderId, colorScheme),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Future<void> _approveResponder(String responderId, ColorScheme colorScheme) async {
    try {
      await _firestore.collection('responders').doc(responderId).update({
        'isVerified': true,
        'verificationStatus': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUser?.uid,
      });
      _showSnackBar('Responder approved successfully!', colorScheme.secondary);
    } catch (e) {
      _showSnackBar('Failed to approve: ${e.toString()}', colorScheme.error);
    }
  }

  Future<void> _rejectResponder(String responderId, ColorScheme colorScheme) async {
    try {
      await _firestore.collection('responders').doc(responderId).update({
        'isVerified': false,
        'verificationStatus': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': _auth.currentUser?.uid,
      });
      _showSnackBar('Responder rejected.', colorScheme.tertiary);
    } catch (e) {
      _showSnackBar('Failed to reject: ${e.toString()}', colorScheme.error);
    }
  }

  void _viewIdCard(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ID Card',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, size: 60, color: Colors.red),
                                SizedBox(height: 10),
                                Text('Failed to load ID card'),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}