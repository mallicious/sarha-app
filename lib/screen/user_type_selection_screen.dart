// lib/screen/user_type_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sarha_app/screen/responder_loginscreen.dart';
import 'home_screen.dart';
import 'responder_dashboard_screen.dart';
import 'login_screen.dart';

class UserTypeSelectionScreen extends StatefulWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  State<UserTypeSelectionScreen> createState() =>
      _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen> {
  bool _isDriverPressed = true;
  bool _isResponderPressed = true;

  // Palette
  final Color _periwinkle = const Color(0xFF9FADF4);
  final Color _teal = const Color(0xFF217C82);
  final Color _deepPlum = const Color(0xFF5E213E);
  final Color _lime = const Color(0xFFDAF561);

  /// CORE FIXED LOGIC
  void _handleNavigation(String selectedType) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
  if (selectedType == 'responder') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ResponderLoginScreen(),
      ),
    );
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }
  return;
}

      // ✅ Logged in → Route directly (unchanged)
      if (selectedType == 'driver') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (selectedType == 'road authority') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ResponderDashboardScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ResponderDashboardScreen(),
          ),
        );
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: _periwinkle,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _deepPlum.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 80,
                    color: _teal,
                  ),
                ),

                const SizedBox(height: 40),

                Text(
                  'Welcome to SARHA',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: _deepPlum,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Choose your account type to proceed',
                  style: TextStyle(
                    fontSize: 16,
                    color: _deepPlum.withOpacity(0.7),
                  ),
                ),

                const SizedBox(height: 50),

                // DRIVER BUTTON
                GestureDetector(
                  onTapDown: (_) => setState(() => _isDriverPressed = true),
                  onTapUp: (_) {
                    setState(() => _isDriverPressed = false);
                    _handleNavigation('driver');
                  },
                  onTapCancel: () => setState(() => _isDriverPressed = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    transform: Matrix4.identity()
                      ..translate(0.0, _isDriverPressed ? 4.0 : 0.0),
                    child: _buildUserTypeButton(
                      icon: Icons.directions_car_filled,
                      title: 'Driver',
                      subtitle: 'Report and detect road hazards',
                      color: Colors.white,
                      textColor: _teal,
                      isPressed: _isDriverPressed,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // RESPONDER BUTTON
                GestureDetector(
                  onTapDown: (_) => setState(() => _isResponderPressed = true),
                  onTapUp: (_) {
                    setState(() => _isResponderPressed = false);
                    _handleNavigation('responder');
                  },
                  onTapCancel: () =>
                      setState(() => _isResponderPressed = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    transform: Matrix4.identity()
                      ..translate(0.0, _isResponderPressed ? 4.0 : 0.0),
                    child: _buildUserTypeButton(
                      icon: Icons.engineering_rounded,
                      title: 'Road Authority',
                      subtitle: 'Manage and resolve reports',
                      color: _deepPlum,
                      textColor: Colors.white,
                      isPressed: _isResponderPressed,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _lime.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.security, color: _deepPlum, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Secure Roadside Monitoring',
                        style: TextStyle(
                          color: _deepPlum,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget _buildUserTypeButton({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required Color textColor,
      required bool isPressed,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _deepPlum.withOpacity(isPressed ? 0.05 : 0.15),
              blurRadius: isPressed ? 4 : 12,
              offset: Offset(0, isPressed ? 2 : 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: textColor, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: textColor.withOpacity(0.5)),
          ],
        ),
      );
    }
  }

