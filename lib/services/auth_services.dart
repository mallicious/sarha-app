// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Stream to track the user's authentication state
  Stream<User?> get userStream => _firebaseAuth.authStateChanges();

  // Sign out and clear user type
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear stored user type and admin status
      await prefs.remove('userType');
      await prefs.remove('isAdmin');
      await prefs.remove('lastLoginTime');
      
      // Sign out from Firebase
      await _firebaseAuth.signOut();
      
      if (kDebugMode) {
        print("✅ User signed out successfully");
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error signing out: $e");
      }
      rethrow;
    }
  }

  // Save user type (driver or responder)
  Future<void> saveUserType(String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userType', userType);
      await prefs.setString('lastLoginTime', DateTime.now().toIso8601String());
      
      if (kDebugMode) {
        print("✅ User type saved: $userType");
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error saving user type: $e");
      }
    }
  }

  // Get saved user type
  Future<String?> getSavedUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userType');
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error getting user type: $e");
      }
      return null;
    }
  }

  // Check if user is admin (for your special access)
  Future<bool> isAdmin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('isAdmin') ?? false;
    } catch (e) {
      return false;
    }
  }

  // Set admin status (use this to give yourself admin access)
  Future<void> setAdminStatus(bool isAdmin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isAdmin', isAdmin);
      
      if (kDebugMode) {
        print("✅ Admin status set to: $isAdmin");
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error setting admin status: $e");
      }
    }
  }

  // Switch user type (admin only)
  Future<void> switchUserType(String newType) async {
    final isAdminUser = await isAdmin();
    if (isAdminUser) {
      await saveUserType(newType);
      if (kDebugMode) {
        print("🔄 Admin switched to: $newType");
      }
    } else {
      throw Exception("Only admins can switch user types");
    }
  }

  // Check if this is first time login (for showing user type selection)
  Future<bool> isFirstTimeLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString('userType');
      return userType == null;
    } catch (e) {
      return true;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (kDebugMode) {
        print("✅ User signed in: ${credential.user?.email}");
      }
      
      return credential;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Sign in error: $e");
      }
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmail(
    String email, 
    String password, 
    String displayName
  ) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await credential.user?.updateDisplayName(displayName);
      
      if (kDebugMode) {
        print("✅ User registered: ${credential.user?.email}");
      }
      
      return credential;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Registration error: $e");
      }
      rethrow;
    }
  }
}