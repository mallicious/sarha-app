// lib/widgets/auth_gate.dart - HANDLES AUTOMATIC ROUTING

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final Color _primaryTeal = const Color(0xFF3C959B);
  final Color _lime = const Color(0xFFDADE5B);

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Wait a moment for Firebase to initialize
    await Future.delayed(const Duration(milliseconds: 500));

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Not logged in - go to user type selection
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/userTypeSelection');
      }
      return;
    }

    // User is logged in - check their saved type
    final prefs = await SharedPreferences.getInstance();
    final userType = prefs.getString('userType');

    if (userType == null) {
      // Logged in but no type saved - go to user type selection
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/userTypeSelection');
      }
      return;
    }

    // Route to appropriate dashboard
    if (mounted) {
      if (userType == 'driver') {
        Navigator.of(context).pushReplacementNamed('/driverDashboard');
      } else if (userType == 'responder') {
        Navigator.of(context).pushReplacementNamed('/responderDashboard');
      } else {
        // Unknown type - go to user type selection
        Navigator.of(context).pushReplacementNamed('/userTypeSelection');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // SARHA Logo/Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _primaryTeal.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: _lime, width: 3),
              ),
              child: Icon(
                Icons.directions_car,
                size: 50,
                color: _lime,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'SARHA',
              style: TextStyle(
                color: _lime,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Road Hazard Assist',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            CircularProgressIndicator(
              color: _lime,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}