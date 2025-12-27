// lib/screen/settings_screen.dart - FIXED WITH PROPER LOGOUT & ADMIN TOGGLE

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // === NEW COLOR PALETTE ===
  final Color _primaryTeal = const Color(0xFF3C959B);
  final Color _darkTeal = const Color(0xFF1F565E);
  final Color _burgundy = const Color(0xFF6E1E42);
  final Color _peach = const Color(0xFFF7AD97);
  final Color _periwinkle = const Color(0xFFA7B6F7);
  final Color _lime = const Color(0xFFDADE5B);
  final Color _lightBg = const Color(0xFFF5F5F5);
  final Color _darkBg = const Color(0xFF1A1A1A);

  // Settings state variables
  bool _notificationsEnabled = true;
  bool _soundAlertsEnabled = true;
  bool _autoDetectionEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedMapType = 'Normal';
  
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _currentUserType;
  int _logoTapCount = 0;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User stats
  int _totalReports = 0;
  int _totalDetections = 0;
  double _distanceTraveled = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserStats();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('isAdmin') ?? false;
      _currentUserType = prefs.getString('userType');
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications') ?? true;
        _soundAlertsEnabled = prefs.getBool('soundAlerts') ?? true;
        _autoDetectionEnabled = prefs.getBool('autoDetection') ?? true;
        _darkModeEnabled = prefs.getBool('darkMode') ?? false;
        _selectedMapType = prefs.getString('mapType') ?? 'Normal';
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading settings: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
      _showSnackBar('Setting saved', _lime);
    } catch (e) {
      _showSnackBar('Failed to save: ${e.toString()}', _burgundy);
    }
  }

  Future<void> _loadUserStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final reportsSnapshot = await _firestore
          .collection('hazards')
          .where('userId', isEqualTo: user.uid)
          .get();

      setState(() {
        _totalReports = reportsSnapshot.docs.length;
        _totalDetections = reportsSnapshot.docs.length;
        _distanceTraveled = 156.5; 
      });
    } catch (e) {
      print("Error loading stats: $e");
    }
  }

  // === LOGOUT FUNCTION ===
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkModeEnabled ? _darkBg : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: _burgundy, size: 28),
            const SizedBox(width: 12),
            Text(
              'Logout',
              style: TextStyle(
                color: _darkModeEnabled ? Colors.white : _darkTeal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout? You will need to sign in again.',
          style: TextStyle(
            color: _darkModeEnabled ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _periwinkle)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _burgundy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Clear all saved preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('userType');
        await prefs.remove('lastLoginTime');
        // Keep isAdmin for next login
        
        // Sign out from Firebase
        await _auth.signOut();
        
        if (mounted) {
          // Navigate to user type selection
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/userTypeSelection',
            (route) => false,
          );
          _showSnackBar('Logged out successfully', _lime);
        }
      } catch (e) {
        _showSnackBar('Logout failed: ${e.toString()}', _burgundy);
      }
    }
  }

  // === ADMIN TOGGLE - LONG PRESS ON LOGO ===
  void _handleLogoTap() {
    _logoTapCount++;
    
    if (_logoTapCount == 7) {
      _showAdminDialog();
      _logoTapCount = 0;
    }

    // Reset counter after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _logoTapCount = 0;
    });
  }

  void _showAdminDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentAdminStatus = prefs.getBool('isAdmin') ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkModeEnabled ? _darkBg : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: _lime, size: 28),
            const SizedBox(width: 12),
            Text(
              'Admin Mode',
              style: TextStyle(
                color: _darkModeEnabled ? Colors.white : _darkTeal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentAdminStatus 
                  ? '🔓 Admin mode is currently ENABLED'
                  : '🔒 Admin mode is currently DISABLED',
              style: TextStyle(
                color: _darkModeEnabled ? Colors.white70 : Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Admin privileges allow you to:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _darkModeEnabled ? Colors.white : _darkTeal,
              ),
            ),
            const SizedBox(height: 8),
            _buildAdminFeature('Switch between Driver & Responder dashboards'),
            _buildAdminFeature('Access admin panel'),
            _buildAdminFeature('Test all app features'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _periwinkle)),
          ),
          ElevatedButton(
            onPressed: () async {
              await prefs.setBool('isAdmin', !currentAdminStatus);
              setState(() {
                _isAdmin = !currentAdminStatus;
              });
              Navigator.pop(context);
              _showSnackBar(
                !currentAdminStatus ? 'Admin mode ENABLED' : 'Admin mode DISABLED',
                !currentAdminStatus ? _lime : _peach,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: currentAdminStatus ? _burgundy : _lime,
              foregroundColor: currentAdminStatus ? Colors.white : _darkTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(currentAdminStatus ? 'Disable Admin' : 'Enable Admin'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: _lime),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: _darkModeEnabled ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === ADMIN SWITCH DASHBOARD ===
  void _showSwitchDashboardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkModeEnabled ? _darkBg : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.swap_horiz, color: _lime, size: 28),
            const SizedBox(width: 12),
            Text(
              'Switch Dashboard',
              style: TextStyle(
                color: _darkModeEnabled ? Colors.white : _darkTeal,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current: ${_currentUserType?.toUpperCase() ?? "UNKNOWN"}',
              style: TextStyle(
                color: _darkModeEnabled ? Colors.white70 : Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            _buildDashboardOption('driver', 'Driver Dashboard', Icons.drive_eta),
            const SizedBox(height: 12),
            _buildDashboardOption('responder', 'Responder Dashboard', Icons.engineering),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardOption(String type, String title, IconData icon) {
    final isSelected = _currentUserType == type;
    return InkWell(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userType', type);
        setState(() => _currentUserType = type);
        Navigator.pop(context);
        
        // Navigate to selected dashboard
        Navigator.of(context).pushNamedAndRemoveUntil(
          type == 'driver' ? '/driverDashboard' : '/responderDashboard',
          (route) => false,
        );
        
        _showSnackBar('Switched to $title', _lime);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _lime.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? _lime : _periwinkle.withOpacity(0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? _lime : _periwinkle),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _darkModeEnabled ? Colors.white : _darkTeal,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Icon(Icons.check_circle, color: _lime, size: 20),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showMapTypeDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkModeEnabled ? _darkBg : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Select Map Type',
          style: TextStyle(
            color: _darkModeEnabled ? Colors.white : _darkTeal,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMapTypeOption('Normal'),
            _buildMapTypeOption('Satellite'),
            _buildMapTypeOption('Terrain'),
            _buildMapTypeOption('Hybrid'),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() => _selectedMapType = result);
      _saveSetting('mapType', result);
    }
  }

  Widget _buildMapTypeOption(String mapType) {
    return RadioListTile<String>(
      title: Text(
        mapType,
        style: TextStyle(color: _darkModeEnabled ? Colors.white : _darkTeal),
      ),
      value: mapType,
      groupValue: _selectedMapType,
      activeColor: _primaryTeal,
      onChanged: (value) => Navigator.pop(context, value),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _darkModeEnabled ? _darkBg : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            GestureDetector(
              onTap: _handleLogoTap,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.info_outline, color: _primaryTeal, size: 28),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'About SARHA',
                style: TextStyle(
                  color: _darkModeEnabled ? Colors.white : _darkTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Smartphone Augmented Reality Road Hazard Assist',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _darkModeEnabled ? Colors.white : _darkTeal,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.verified, 'Version: 1.0.0'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.person, 'Developer: Okemini Malvina Amarachi'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.school, 'Nile University of Nigeria'),
              const SizedBox(height: 12),
              Text(
                'SARHA uses advanced sensor fusion to detect road hazards in real-time, making roads safer for everyone.',
                style: TextStyle(
                  fontSize: 13,
                  color: _darkModeEnabled ? Colors.white70 : Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '© 2024 SARHA. All rights reserved.',
                style: TextStyle(
                  fontSize: 11,
                  color: _darkModeEnabled ? Colors.white38 : Colors.black38,
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _lime.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _lime),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.admin_panel_settings, color: _lime, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Admin Mode Active',
                        style: TextStyle(
                          fontSize: 11,
                          color: _darkModeEnabled ? Colors.white : _darkTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: _primaryTeal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _periwinkle),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: _darkModeEnabled ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final bgColor = _darkModeEnabled ? _darkBg : _lightBg;
    final cardColor = _darkModeEnabled ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = _darkModeEnabled ? Colors.white : _darkTeal;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: CircularProgressIndicator(color: _primaryTeal),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: Icon(Icons.swap_horiz, color: _lime),
              tooltip: 'Switch Dashboard',
              onPressed: _showSwitchDashboardDialog,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryTeal, _darkTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _handleLogoTap,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: Text(
                            user?.displayName?.substring(0, 1).toUpperCase() ?? 
                            user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                            style: TextStyle(
                              fontSize: 40,
                              color: _primaryTeal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (_isAdmin)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _lime,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.admin_panel_settings, size: 16, color: _darkTeal),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/editProfile');
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _lime,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(Icons.edit, size: 18, color: _darkTeal),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'No email',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  if (_currentUserType != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Text(
                        _currentUserType!.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/editProfile'),
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _primaryTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // App Settings
            _buildSection(
              'App Settings',
              Icons.tune,
              textColor,
              cardColor,
              [
                _buildSwitchTile(
                  icon: Icons.notifications_active,
                  title: 'Push Notifications',
                  subtitle: 'Receive hazard alerts',
                  value: _notificationsEnabled,
                  textColor: textColor,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    _saveSetting('notifications', value);
                  },
                ),
                _buildSwitchTile(
                  icon: Icons.volume_up,
                  title: 'Voice Alerts',
                  subtitle: 'Audio warnings while driving',
                  value: _soundAlertsEnabled,
                  textColor: textColor,
                  onChanged: (value) {
                    setState(() => _soundAlertsEnabled = value);
                    _saveSetting('soundAlerts', value);
                  },
                ),
                _buildSwitchTile(
                  icon: Icons.sensors,
                  title: 'Auto-Detection',
                  subtitle: 'Sensor fusion hazard detection',
                  value: _autoDetectionEnabled,
                  textColor: textColor,
                  onChanged: (value) {
                    setState(() => _autoDetectionEnabled = value);
                    _saveSetting('autoDetection', value);
                  },
                ),
                _buildSwitchTile(
                  icon: Icons.dark_mode,
                  title: 'Dark Mode',
                  subtitle: 'Switch to dark theme',
                  value: _darkModeEnabled,
                  textColor: textColor,
                  onChanged: (value) {
                    setState(() => _darkModeEnabled = value);
                    _saveSetting('darkMode', value);
                  },
                ),
              ],
            ),

            // Map Settings
            _buildSection(
              'Map Preferences',
              Icons.map_outlined,
              textColor,
              cardColor,
              [
                _buildListTile(
                  icon: Icons.layers,
                  title: 'Map Type',
                  subtitle: _selectedMapType,
                  textColor: textColor,
                  onTap: _showMapTypeDialog,
                ),
              ],
            ),

            // Statistics
            _buildSection(
              'Your Statistics',
              Icons.bar_chart,
              textColor,
              cardColor,
              [
                _buildStatTile(
                  icon: Icons.report_gmailerrorred,
                  title: 'Manual Reports',
                  value: _totalReports.toString(),
                  color: _peach,
                  textColor: textColor,
                ),
                _buildStatTile(
                  icon: Icons.sensors,
                  title: 'Auto Detections',
                  value: _totalDetections.toString(),
                  color: _lime,
                  textColor: textColor,
                ),
                _buildStatTile(
                  icon: Icons.directions_car,
                  title: 'Distance Traveled',
                  value: '${_distanceTraveled.toStringAsFixed(1)} km',
                  color: _periwinkle,
                  textColor: textColor,
                ),
              ],
            ),

            // Other Options
            _buildSection(
              'More',
              Icons.more_horiz,
              textColor,
              cardColor,
              [
                _buildListTile(
                  icon: Icons.info_outline,
                  title: 'About SARHA',
                  subtitle: 'Version 1.0.0',
                  textColor: textColor,
                  onTap: _showAboutDialog,
                ),
                _buildListTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we protect your data',
                  textColor: textColor,
                  onTap: () {
                    _showSnackBar('Coming soon', _periwinkle);
                  },
                ),
                _buildListTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  subtitle: 'Get assistance',
                  textColor: textColor,
                  onTap: () {
                    _showSnackBar('Coming soon', _periwinkle);
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.white, size: 22),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _burgundy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    Color textColor,
    Color cardColor,
    List<Widget> children,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
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
          Row(
            children: [
              Icon(icon, color: _primaryTeal, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color textColor,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primaryTeal, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
        ),
        value: value,
        activeColor: _lime,
        activeTrackColor: _lime.withOpacity(0.5),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primaryTeal, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 15),
        ),
        subtitle: subtitle != null 
          ? Text(subtitle, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)))
          : null,
        trailing: Icon(Icons.chevron_right, color: textColor.withOpacity(0.4)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}