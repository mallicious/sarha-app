import 'package:flutter/material.dart';
import 'dart:math' as math;

class ArHazardSimulation extends StatefulWidget {
  const ArHazardSimulation({super.key});

  @override
  State<ArHazardSimulation> createState() => _ArHazardSimulation();
}

class _ArHazardSimulation extends State<ArHazardSimulation>
    with SingleTickerProviderStateMixin {
  List<Offset> hazardMarkers = [];
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Hazard Detector',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF9E9EF8),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() {
                hazardMarkers.clear();
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Simulated camera view
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey[300]!,
                  Colors.grey[400]!,
                ],
              ),
            ),
            child: CustomPaint(
              painter: ARSimulationPainter(
                markers: hazardMarkers,
                animation: _controller,
              ),
              size: Size.infinite,
            ),
          ),

          // Demo mode banner
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Text(
                    '🎯 AR SIMULATION MODE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Demonstrating AR functionality (Requires physical device for full AR)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Simulated plane detection overlay
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: PlaneDetectionPainter(_controller.value),
                );
              },
            ),
          ),

          // Tap to place
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) {
                setState(() {
                  hazardMarkers.add(details.localPosition);
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Hazard marker placed! Total: ${hazardMarkers.length}'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ),

          // Instructions
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.touch_app,
                      color: Color(0xFF9E9EF8), size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    "TAP anywhere to place hazard markers",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Markers placed: ${hazardMarkers.length}",
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ARSimulationPainter extends CustomPainter {
  final List<Offset> markers;
  final Animation<double> animation;

  ARSimulationPainter({required this.markers, required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid lines to simulate surface detection
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1;

    for (var i = 0; i < 10; i++) {
      final y = size.height * (0.3 + i * 0.07);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Draw hazard markers
    for (var marker in markers) {
      _drawHazardMarker(canvas, marker);
    }
  }

  void _drawHazardMarker(Canvas canvas, Offset position) {
    // Pulsing circle
    final circlePaint = Paint()
      ..color = Colors.red
          .withOpacity(0.3 + 0.3 * math.sin(animation.value * 2 * math.pi))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(position, 30, circlePaint);

    // Warning icon
    final iconPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // Draw warning triangle
    final path = Path()
      ..moveTo(position.dx, position.dy - 15)
      ..lineTo(position.dx - 12, position.dy + 10)
      ..lineTo(position.dx + 12, position.dy + 10)
      ..close();

    canvas.drawPath(path, iconPaint);

    // Exclamation mark
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '!',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy - 5),
    );
  }

  @override
  bool shouldRepaint(ARSimulationPainter oldDelegate) => true;
}

class PlaneDetectionPainter extends CustomPainter {
  final double progress;

  PlaneDetectionPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Animated scanning line
    final y = size.height * progress;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      paint
        ..color = Colors.cyan.withOpacity(0.5)
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(PlaneDetectionPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
