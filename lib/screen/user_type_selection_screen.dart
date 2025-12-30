import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'responder_loginscreen.dart';
import 'home_screen.dart';
import 'responder_dashboard_screen.dart';
import 'login_screen.dart';

class UserTypeSelectionScreen extends StatefulWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  State<UserTypeSelectionScreen> createState() => _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen> {
  // === CALM COLOR PALETTE ===
  static const Color softLavender = Color(0xFFA7B5F4);
  static const Color coral = Color(0xFFFF9B85);
  static const Color cream = Color(0xFFFAF8F5);
  static const Color deepPurple = Color(0xFF4A4063);
  static const Color lightPurple = Color(0xFFD1D5F7);

  bool _isDriverPressed = false;
  bool _isResponderPressed = false;

 @override
void initState() {
  super.initState();
  _checkAutoLogin();
}

Future<void> _checkAutoLogin() async {
  final prefs = await SharedPreferences.getInstance();
  final stayLoggedIn = prefs.getBool('stayLoggedIn') ?? false;
  final userType = prefs.getString('userType');
  final loginTimestamp = prefs.getInt('loginTimestamp');
  
  print('🔍 Auto-login check: stayLoggedIn=$stayLoggedIn, userType=$userType');
  
  if (!stayLoggedIn || userType == null) {
    print('❌ No auto-login: stay=$stayLoggedIn, type=$userType');
    return;
  }

  // Check if 2 weeks have passed
  if (loginTimestamp != null) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final twoWeeksInMs = 14 * 24 * 60 * 60 * 1000;
    
    if (now - loginTimestamp > twoWeeksInMs) {
      print('⏰ Login expired (>2 weeks)');
      await prefs.remove('stayLoggedIn');
      await prefs.remove('loginTimestamp');
      return;
    }
  }

  // Check if user is actually logged into Firebase
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && mounted) {
    print('✅ Auto-login successful! Navigating to $userType dashboard');
    
    // Small delay to show splash/logo
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (userType == 'driver') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (userType == 'responder') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ResponderDashboardScreen()),
      );
    }
  } else {
    print('❌ No Firebase user found');
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
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
                  gradient: LinearGradient(
                    colors: [softLavender, lightPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: softLavender.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(Icons.warning_amber_rounded, size: 80, color: Colors.white),
              ),

              const SizedBox(height: 40),

              Text(
                'Welcome to SARHA',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: deepPurple),
              ),

              const SizedBox(height: 10),

              Text(
                'Choose your account type to proceed',
                style: TextStyle(fontSize: 16, color: deepPurple.withOpacity(0.6)),
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
                  transform: Matrix4.identity()..translate(0.0, _isDriverPressed ? 4.0 : 0.0),
                  child: _buildUserTypeButton(
                    icon: Icons.directions_car_filled_rounded,
                    title: 'Driver',
                    subtitle: 'Report and detect road hazards',
                    color: softLavender,
                    textColor: Colors.white,
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
                onTapCancel: () => setState(() => _isResponderPressed = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  transform: Matrix4.identity()..translate(0.0, _isResponderPressed ? 4.0 : 0.0),
                  child: _buildUserTypeButton(
                    icon: Icons.engineering_rounded,
                    title: 'Road Authority',
                    subtitle: 'Manage and resolve reports',
                    color: coral,
                    textColor: Colors.white,
                    isPressed: _isResponderPressed,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: lightPurple.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.security_rounded, color: deepPurple, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Secure Roadside Monitoring',
                      style: TextStyle(color: deepPurple, fontWeight: FontWeight.bold, fontSize: 12),
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
            color: Colors.black.withOpacity(isPressed ? 0.05 : 0.1),
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
              color: Colors.white.withOpacity(0.2),
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.9)),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: textColor.withOpacity(0.7)),
        ],
      ),
    );
  }

  void _handleNavigation(String userType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userType', userType);
    await prefs.setBool('stayLoggedIn', false);
    await prefs.remove('loginTimestamp');

    if (userType == 'driver') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else if (userType == 'responder') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ResponderLoginScreen()),
      );
    }
  }
}
