// lib/widgets/hazard_legend_widget.dart

import 'package:flutter/material.dart';

class HazardLegendWidget extends StatelessWidget {
  const HazardLegendWidget({super.key});

  // Define the hazard types and their corresponding colors
  final Map<String, Color> hazardTypes = const {
    'Pothole': Color(0xFFC62828), // Red
    'Crack': Color(0xFFFFA000),    // Amber/Orange
    'Bump': Color(0xFF43A047),     // Green
    'Debris': Color(0xFF5E35B1),   // Deep Purple
    'Road Sign Issue': Color(0xFF00ACC1), // Cyan
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.all(10.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hazard Legend',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF00897B),
              ),
            ),
            const Divider(height: 8),
            ...hazardTypes.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.key,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}