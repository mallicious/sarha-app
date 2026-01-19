import 'package:share_plus/share_plus.dart';
import 'dart:io';

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  // Share hazard report
  Future<void> shareHazard({
    required String hazardType,
    required String description,
    required double latitude,
    required double longitude,
    String? imagePath,
  }) async {
    try {
      final message = '''
⚠️ Road Hazard Alert!

Type: $hazardType
Location: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}
Description: $description

📍 View on Maps: https://maps.google.com/?q=$latitude,$longitude

Shared via SARHA - Making Roads Safer Together 🚗
#RoadSafety #SARHA
''';

      if (imagePath != null && await File(imagePath).exists()) {
        await Share.shareXFiles(
          [XFile(imagePath)],
          text: message,
          subject: 'Road Hazard Alert',
        );
      } else {
        await Share.share(
          message,
          subject: 'Road Hazard Alert',
        );
      }

      print('✅ Hazard shared successfully');
    } catch (e) {
      print('❌ Share error: $e');
    }
  }

  // Share user stats
  Future<void> shareStats({
    required int totalReports,
    required int detectionsCount,
    required double distanceTraveled,
  }) async {
    try {
      final message = '''
📊 My SARHA Impact Report

🚗 Reports Submitted: $totalReports
🔍 Auto-Detections: $detectionsCount
📏 Distance Traveled: ${distanceTraveled.toStringAsFixed(1)}km

Making our roads safer, one report at a time! 🛣️

Download SARHA and help make roads safer for everyone.
#RoadSafety #SARHA #MakingADifference
''';

      await Share.share(
        message,
        subject: 'My SARHA Stats',
      );

      print('✅ Stats shared successfully');
    } catch (e) {
      print('❌ Share error: $e');
    }
  }

  // Share app download link
  Future<void> shareApp() async {
    try {
      const message = '''
🚗 Check out SARHA - Road Hazard Detection App!

SARHA helps make our roads safer by:
✅ Detecting road hazards in real-time
✅ Alerting drivers of dangers ahead
✅ Helping authorities respond faster

Download now and join the road safety movement! 🛣️

#RoadSafety #SARHA #SmartDriving
''';

      await Share.share(
        message,
        subject: 'SARHA - Making Roads Safer',
      );

      print('✅ App shared successfully');
    } catch (e) {
      print('❌ Share error: $e');
    }
  }
}



