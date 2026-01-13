import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class ResponderAnalyticsScreen extends StatefulWidget {
  const ResponderAnalyticsScreen({super.key});

  @override
  State<ResponderAnalyticsScreen> createState() => _ResponderAnalyticsScreenState();
}

class _ResponderAnalyticsScreenState extends State<ResponderAnalyticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color backgroundBlue = Color(0xFFE5F4FF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkBlue = Color(0xFF1C3A5E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: primaryBlue,
        foregroundColor: white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('hazards').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryBlue));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final hazards = snapshot.data!.docs;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCards(hazards),
                const SizedBox(height: 24),
                _buildHazardTypeChart(hazards),
                const SizedBox(height: 24),
                _buildStatusBreakdown(hazards),
                const SizedBox(height: 24),
                _buildRecentTrends(hazards),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCards(List<QueryDocumentSnapshot> hazards) {
    final total = hazards.length;
    final pending = hazards.where((d) => (d.data() as Map)['status'] == 'pending').length;
    final resolved = hazards.where((d) => (d.data() as Map)['status'] == 'fixed').length;
    final resolveRate = total > 0 ? ((resolved / total) * 100).toStringAsFixed(1) : '0.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Reports',
                total.toString(),
                Icons.assignment_rounded,
                primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Resolve Rate',
                '$resolveRate%',
                Icons.trending_up_rounded,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(16),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: darkBlue.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHazardTypeChart(List<QueryDocumentSnapshot> hazards) {
    // Count hazards by type
    final typeCounts = <String, int>{};
    for (var hazard in hazards) {
      final type = (hazard.data() as Map)['type'] ?? 'Other';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }

    // Sort by count
    final sortedTypes = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            'Hazard Types',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: sortedTypes.isNotEmpty ? sortedTypes.first.value.toDouble() + 2 : 10,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sortedTypes.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _shortenType(sortedTypes[value.toInt()].key),
                              style: const TextStyle(
                                fontSize: 10,
                                color: darkBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: darkBlue),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: darkBlue.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: sortedTypes.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value.toDouble(),
                        color: _getTypeColor(entry.value.key),
                        width: 30,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdown(List<QueryDocumentSnapshot> hazards) {
    final pending = hazards.where((d) => (d.data() as Map)['status'] == 'pending').length;
    final resolved = hazards.where((d) => (d.data() as Map)['status'] == 'fixed').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            'Status Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 20),
          _buildStatusBar('Pending', pending, Colors.orange),
          const SizedBox(height: 12),
          _buildStatusBar('Resolved', resolved, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatusBar(String label, int count, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: darkBlue,
              ),
            ),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: count / (count + 1), // Placeholder calculation
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTrends(List<QueryDocumentSnapshot> hazards) {
    // Get reports from last 7 days
    final now = DateTime.now();
    final last7Days = now.subtract(const Duration(days: 7));
    
    final recentHazards = hazards.where((hazard) {
      final data = hazard.data() as Map<String, dynamic>;
      if (data['timestamp'] == null) return false;
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      return timestamp.isAfter(last7Days);
    }).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.trending_up_rounded, color: primaryBlue, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$recentHazards reports',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue,
                      ),
                    ),
                    Text(
                      'in the last 7 days',
                      style: TextStyle(
                        fontSize: 14,
                        color: darkBlue.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: darkBlue.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'No data available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: darkBlue.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analytics will appear once reports are submitted',
            style: TextStyle(
              fontSize: 14,
              color: darkBlue.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _shortenType(String type) {
    if (type.length <= 8) return type;
    return '${type.substring(0, 7)}...';
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'pothole':
        return Colors.red;
      case 'flooding':
        return Colors.blue;
      case 'roadwork':
        return Colors.orange;
      case 'debris':
        return Colors.brown;
      case 'street light':
        return Colors.yellow.shade700;
      case 'speed bump':
        return Colors.purple;
      default:
        return primaryBlue;
    }
  }
}