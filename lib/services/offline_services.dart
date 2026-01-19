import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;

  // Check connectivity status
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    return _isOnline;
  }

  // Listen to connectivity changes
  Stream<bool> onConnectivityChanged() {
    return _connectivity.onConnectivityChanged.map((result) {
      _isOnline = result != ConnectivityResult.none;
      if (_isOnline) {
        _syncOfflineData(); // Auto-sync when back online
      }
      return _isOnline;
    });
  }

  // Save hazard offline
  Future<void> saveHazardOffline(Map<String, dynamic> hazardData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing offline hazards
      final offlineHazards = prefs.getStringList('offline_hazards') ?? [];
      
      // Add new hazard
      offlineHazards.add(jsonEncode(hazardData));
      
      // Save back
      await prefs.setStringList('offline_hazards', offlineHazards);
      
      print('💾 Hazard saved offline (${offlineHazards.length} pending)');
    } catch (e) {
      print('❌ Offline save error: $e');
    }
  }

  // Get offline hazard count
  Future<int> getOfflineCount() async {
    final prefs = await SharedPreferences.getInstance();
    final offlineHazards = prefs.getStringList('offline_hazards') ?? [];
    return offlineHazards.length;
  }

  // Sync offline data
  Future<void> _syncOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineHazards = prefs.getStringList('offline_hazards') ?? [];
      
      if (offlineHazards.isEmpty) return;
      
      print('🔄 Syncing ${offlineHazards.length} offline hazards...');
      
      int successCount = 0;
      List<String> failedHazards = [];
      
      for (final hazardJson in offlineHazards) {
        try {
          final hazardData = jsonDecode(hazardJson) as Map<String, dynamic>;
          
          // Upload to Firestore
          await FirebaseFirestore.instance
              .collection('hazards')
              .add(hazardData);
          
          successCount++;
        } catch (e) {
          print('❌ Failed to sync hazard: $e');
          failedHazards.add(hazardJson);
        }
      }
      
      // Keep only failed hazards
      await prefs.setStringList('offline_hazards', failedHazards);
      
      print('✅ Synced $successCount hazards, ${failedHazards.length} failed');
    } catch (e) {
      print('❌ Sync error: $e');
    }
  }

  // Manual sync trigger
  Future<bool> syncNow() async {
    if (!await isOnline()) {
      print('❌ Cannot sync: No internet connection');
      return false;
    }
    
    await _syncOfflineData();
    return true;
  }

  // Cache hazards for offline viewing
  Future<void> cacheHazards(List<QueryDocumentSnapshot> hazards) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cachedHazards = hazards.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return jsonEncode(data);
      }).toList();
      
      await prefs.setStringList('cached_hazards', cachedHazards);
      
      print('💾 Cached ${hazards.length} hazards for offline use');
    } catch (e) {
      print('❌ Cache error: $e');
    }
  }

  // Get cached hazards
  Future<List<Map<String, dynamic>>> getCachedHazards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedHazards = prefs.getStringList('cached_hazards') ?? [];
      
      return cachedHazards
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('❌ Get cache error: $e');
      return [];
    }
  }
}

// Usage in your app:
// 1. Show offline indicator
Widget _buildOfflineIndicator(bool isOnline) {
  if (isOnline) return const SizedBox.shrink();
  
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    color: Colors.orange,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        const Text(
          'Offline Mode - Data will sync when connected',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

