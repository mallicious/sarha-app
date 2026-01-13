import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Log app open
  Future<void> logAppOpen() async {
    await _logEvent('app_open', {
      'timestamp': FieldValue.serverTimestamp(),
      'platform': 'android', // or iOS
    });
  }

  // Log hazard report
  Future<void> logHazardReport(String hazardType, String detectionMethod) async {
    await _logEvent('hazard_reported', {
      'hazard_type': hazardType,
      'detection_method': detectionMethod, // 'manual' or 'auto'
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Log hazard view
  Future<void> logHazardView(String hazardId) async {
    await _logEvent('hazard_viewed', {
      'hazard_id': hazardId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Log feature usage
  Future<void> logFeatureUsed(String featureName) async {
    await _logEvent('feature_used', {
      'feature': featureName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Log screen view
  Future<void> logScreenView(String screenName) async {
    await _logEvent('screen_view', {
      'screen_name': screenName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Internal log method
  Future<void> _logEvent(String eventName, Map<String, dynamic> data) async {
    try {
      final userId = _auth.currentUser?.uid ?? 'anonymous';
      
      await _firestore.collection('analytics').add({
        'event_name': eventName,
        'user_id': userId,
        ...data,
      });
      
      print('📊 Analytics: $eventName logged');
    } catch (e) {
      print('❌ Analytics error: $e');
    }
  }

  // Get user statistics
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final hazards = await _firestore
          .collection('hazards')
          .where('userId', isEqualTo: userId)
          .get();

      final manualReports = hazards.docs
          .where((doc) => (doc.data()['detectionMethod'] ?? 'manual') == 'manual')
          .length;

      final autoDetections = hazards.docs
          .where((doc) => (doc.data()['detectionMethod'] ?? 'manual') == 'auto')
          .length;

      return {
        'total_reports': hazards.docs.length,
        'manual_reports': manualReports,
        'auto_detections': autoDetections,
        'impact_score': hazards.docs.length * 10, // Points system
      };
    } catch (e) {
      print('❌ Stats error: $e');
      return {};
    }
  }

  // Get global statistics (for dashboard)
  Future<Map<String, dynamic>> getGlobalStats() async {
    try {
      final hazards = await _firestore.collection('hazards').get();
      final users = await _firestore.collection('users').get();

      final pending = hazards.docs
          .where((doc) => (doc.data()['status'] ?? 'pending') == 'pending')
          .length;

      final resolved = hazards.docs
          .where((doc) => (doc.data()['status'] ?? 'pending') == 'fixed')
          .length;

      return {
        'total_hazards': hazards.docs.length,
        'pending_hazards': pending,
        'resolved_hazards': resolved,
        'total_users': users.docs.length,
        'resolution_rate': resolved / hazards.docs.length * 100,
      };
    } catch (e) {
      print('❌ Global stats error: $e');
      return {};
    }
  }
}