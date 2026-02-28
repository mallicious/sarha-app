import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'hazard_map_previewscreen.dart';

class ResponderDashboardScreen extends StatefulWidget {
  const ResponderDashboardScreen({super.key});

  @override
  State<ResponderDashboardScreen> createState() =>
      _ResponderDashboardScreenState();
}

class _ResponderDashboardScreenState extends State<ResponderDashboardScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _filterStatus = 'all';
  late TabController _tabController;

  // === DARK PROFESSIONAL PALETTE ===
  static const Color bg = Color(0xFF0F1117);
  static const Color surface = Color(0xFF1A1D27);
  static const Color card = Color(0xFF222534);
  static const Color accent = Color(0xFF6C8EF5);
  static const Color accentGreen = Color(0xFF4ADE80);
  static const Color accentOrange = Color(0xFFFF9B85);
  static const Color textPrimary = Color(0xFFEEF0F8);
  static const Color textMuted = Color(0xFF8B8FA8);
  static const Color divider = Color(0xFF2A2D3E);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _filterStatus = 'all';
            break;
          case 1:
            _filterStatus = 'pending';
            break;
          case 2:
            _filterStatus = 'fixed';
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStatsRow(),
            _buildTabBar(),
            Expanded(child: _buildHazardList()),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SARHA Command',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: accentGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Live monitoring active',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          FutureBuilder<DocumentSnapshot>(
            future: _firestore
                .collection('responders')
                .doc(_auth.currentUser?.uid)
                .get(),
            builder: (context, snapshot) {
              final data =
                  snapshot.data?.data() as Map<String, dynamic>? ?? {};
              final isAdmin = data['isAdmin'] ?? false;
              return Row(
                children: [
                  if (isAdmin)
                    _iconBtn(Icons.admin_panel_settings_rounded, () {
                      Navigator.pushNamed(context, '/adminPanel');
                    }),
                  const SizedBox(width: 8),
                  _iconBtn(Icons.logout_rounded, () async {
                    await _auth.signOut();
                    if (mounted) {
                      Navigator.pushReplacementNamed(context, '/');
                    }
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: divider),
        ),
        child: Icon(icon, color: textMuted, size: 20),
      ),
    );
  }

  // ============================================================
  // STATS ROW
  // ============================================================
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('hazards').snapshots(),
      builder: (context, snapshot) {
        final hazards = snapshot.data?.docs ?? [];
        final total = hazards.length;
        final pending = hazards
            .where((d) =>
                ((d.data() as Map)['status'] ?? 'pending') != 'fixed')
            .length;
        final fixed = total - pending;
        final todayCount = hazards.where((d) {
          final ts = (d.data() as Map)['timestamp'];
          if (ts == null) return false;
          final date = (ts as Timestamp).toDate();
          final now = DateTime.now();
          return date.day == now.day &&
              date.month == now.month &&
              date.year == now.year;
        }).length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              _buildStatTile('TOTAL', total.toString(), accent, Icons.layers_rounded),
              const SizedBox(width: 10),
              _buildStatTile('ACTIVE', pending.toString(), accentOrange,
                  Icons.pending_actions_rounded),
              const SizedBox(width: 10),
              _buildStatTile('FIXED', fixed.toString(), accentGreen,
                  Icons.check_circle_rounded),
              const SizedBox(width: 10),
              _buildStatTile('TODAY', todayCount.toString(),
                  const Color(0xFFB794F4), Icons.today_rounded),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatTile(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAB BAR
  // ============================================================
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: divider),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: accent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.4)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: accent,
        unselectedLabelColor: textMuted,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'All Reports'),
          Tab(text: 'Active'),
          Tab(text: 'Resolved'),
        ],
      ),
    );
  }

  // ============================================================
  // HAZARD LIST
  // ============================================================
  Widget _buildHazardList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('hazards')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
                color: accent, strokeWidth: 2),
          );
        }

        var hazards = snapshot.data!.docs;
        if (_filterStatus != 'all') {
          hazards = hazards.where((doc) {
            final status =
                (doc.data() as Map)['status'] ?? 'pending';
            return status == _filterStatus;
          }).toList();
        }

        if (hazards.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded,
                    size: 56, color: textMuted.withOpacity(0.4)),
                const SizedBox(height: 16),
                Text(
                  _filterStatus == 'fixed'
                      ? 'No resolved reports yet'
                      : _filterStatus == 'pending'
                          ? 'No active hazards'
                          : 'No reports found',
                  style: TextStyle(color: textMuted, fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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

  // ============================================================
  // HAZARD CARD
  // ============================================================
  Widget _buildHazardCard(String hazardId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'pending';
    final isFixed = status == 'fixed';
    final type = data['type'] ?? 'Hazard';
    final confidence = (data['confidence'] ?? 0.0) as double;
    final cardAccent = isFixed ? accentGreen : accentOrange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardAccent.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Top row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                // Hazard type icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cardAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getHazardIcon(type),
                    color: cardAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatTimestamp(data['timestamp']),
                        style:
                            TextStyle(color: textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cardAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: cardAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: cardAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isFixed ? 'Resolved' : 'Active',
                        style: TextStyle(
                          color: cardAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              data['description'] ?? 'No description provided',
              style: TextStyle(
                color: textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Confidence bar — only show if confidence > 0
          if (confidence > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Confidence',
                    style: TextStyle(color: textMuted, fontSize: 11),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: confidence,
                        backgroundColor: divider,
                        valueColor: AlwaysStoppedAnimation(cardAccent),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(confidence * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: cardAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // Divider
          Container(height: 1, color: divider),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // View on map
                Expanded(
                  child: _actionBtn(
                    icon: Icons.map_rounded,
                    label: 'View Map',
                    color: accent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              HazardMapPreviewScreen(
                            hazardId: hazardId,
                            latitude: data['latitude'] ?? 0.0,
                            longitude: data['longitude'] ?? 0.0,
                            hazardType: type,
                            description: data['description'] ??
                                'No description',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (!isFixed) ...[
                  const SizedBox(width: 8),
                  // Mark resolved
                  Expanded(
                    child: _actionBtn(
                      icon: Icons.check_rounded,
                      label: 'Mark Resolved',
                      color: accentGreen,
                      onTap: () => _markAsFixed(hazardId),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      final DateTime dt = (timestamp as Timestamp).toDate();
      final Duration diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
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
      _showSnackBar('✅ Hazard marked as resolved', accentGreen);
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', accentOrange);
    }
  }

  IconData _getHazardIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'pothole':
        return Icons.dangerous_rounded;
      case 'speed bump':
        return Icons.speed_rounded;
      case 'rough road':
        return Icons.warning_amber_rounded;
      case 'flooding':
        return Icons.water_rounded;
      case 'construction':
        return Icons.construction_rounded;
      default:
        return Icons.warning_rounded;
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}