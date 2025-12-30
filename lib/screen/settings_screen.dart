import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sarha_app/services/voice_navigation_services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // === VINTAGE EARTH-TONE PALETTE ===
  static const Color sageGreen = Color(0xFF7E8E7C);
  static const Color dustyRose = Color(0xFFA17A74);
  static const Color vintageCream = Color(0xFFDBC9AC);
  static const Color earthBrown = Color(0xFF8D7B68);
  static const Color lightTan = Color(0xFFE8DFD0);

  // Settings state
  String? _profilePicUrl;
  bool _notificationsEnabled = true;
  bool _soundAlertsEnabled = true;
  bool _autoDetectionEnabled = true;
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
      _currentUserType = prefs.getString('responder') ?? prefs.getString('userType');
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = _auth.currentUser;
      
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications') ?? true;
        _soundAlertsEnabled = prefs.getBool('soundAlerts') ?? true;
        _autoDetectionEnabled = prefs.getBool('autoDetection') ?? true;
        _selectedMapType = prefs.getString('mapType') ?? 'Normal';
      });

      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          setState(() {
            _profilePicUrl = data?['profilePicUrl'];
          });
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading settings: $e', dustyRose);
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
        if (key == 'soundAlerts') {
          VoiceNavigationService().setVoiceEnabled(value);
        }
      } else if (value is String) {
        await prefs.setString(key, value);
      }
      _showSnackBar('Setting saved', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to save setting', dustyRose);
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
      debugPrint("Error loading stats: $e");
    }
  }

  // ==========================================
  // UPDATED LOGOUT LOGIC
  // ==========================================
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: vintageCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: dustyRose, size: 28),
            const SizedBox(width: 12),
            Text('Logout', style: TextStyle(color: earthBrown, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to logout? You will need to sign in again.',
          style: TextStyle(color: earthBrown.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: sageGreen)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: dustyRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Sign out of Firebase
        await _auth.signOut();

        // 2. Clear Persistence SharedPrefs
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('stayLoggedIn');
        await prefs.remove('loginTimestamp');
        await prefs.remove('responder');
        await prefs.remove('userType'); // Clearing both variations to be safe

        if (mounted) {
          // 3. Navigate to User Type Selection and wipe the history stack
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/userTypeSelection', 
            (route) => false
          );
          _showSnackBar('Logged out successfully', Colors.green);
        }
      } catch (e) {
        _showSnackBar('Logout failed: $e', dustyRose);
      }
    }
  }

  void _handleLogoTap() {
    _logoTapCount++;
    if (_logoTapCount == 7) {
      _showAdminDialog();
      _logoTapCount = 0;
    }
    Future.delayed(const Duration(seconds: 3), () => _logoTapCount = 0);
  }

  void _showAdminDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentAdminStatus = prefs.getBool('isAdmin') ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: vintageCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: sageGreen, size: 28),
            const SizedBox(width: 12),
            Text('Admin Mode', style: TextStyle(color: earthBrown, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          currentAdminStatus 
              ? '🔓 Admin mode is currently ENABLED'
              : '🔒 Admin mode is currently DISABLED',
          style: TextStyle(color: earthBrown.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: sageGreen)),
          ),
          ElevatedButton(
            onPressed: () async {
              await prefs.setBool('isAdmin', !currentAdminStatus);
              setState(() => _isAdmin = !currentAdminStatus);
              Navigator.pop(context);
              _showSnackBar(
                !currentAdminStatus ? 'Admin mode enabled' : 'Admin mode disabled',
                Colors.green,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: currentAdminStatus ? dustyRose : Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              currentAdminStatus ? 'Disable' : 'Enable',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showSwitchDashboardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: vintageCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.swap_horiz_rounded, color: sageGreen, size: 28),
            const SizedBox(width: 12),
            Text('Switch Dashboard', style: TextStyle(color: earthBrown, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDashboardOption('driver', 'Driver Dashboard', Icons.drive_eta_rounded),
            const SizedBox(height: 12),
            _buildDashboardOption('responder', 'Responder Dashboard', Icons.engineering_rounded),
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
        await prefs.setString('responder', type); // Using 'responder' to match main.dart
        setState(() => _currentUserType = type);
        Navigator.pop(context);
        Navigator.of(context).pushNamedAndRemoveUntil(
          type == 'driver' ? '/driverDashboard' : '/responderDashboard',
          (route) => false,
        );
        _showSnackBar('Switched to $title', Colors.green);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? sageGreen.withOpacity(0.2) : Colors.transparent,
          border: Border.all(color: isSelected ? sageGreen : lightTan, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? sageGreen : earthBrown),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: earthBrown)),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: sageGreen, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showMapTypeDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: vintageCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Select Map Type', style: TextStyle(color: earthBrown, fontWeight: FontWeight.bold)),
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
      title: Text(mapType, style: TextStyle(color: earthBrown)),
      value: mapType,
      groupValue: _selectedMapType,
      activeColor: sageGreen,
      onChanged: (value) => Navigator.pop(context, value),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: vintageCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            GestureDetector(
              onTap: _handleLogoTap,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: sageGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.info_outline_rounded, color: sageGreen, size: 28),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('About SARHA', style: TextStyle(color: earthBrown, fontWeight: FontWeight.bold)),
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: earthBrown),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.verified_rounded, 'Version: 1.0.0'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.person_rounded, 'Developer: Okemini Malvina Amarachi'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.school_rounded, 'Nile University of Nigeria'),
              const SizedBox(height: 16),
              Text(
                'SARHA uses advanced sensor fusion to detect road hazards in real-time, making roads safer for everyone.',
                style: TextStyle(fontSize: 13, color: earthBrown.withOpacity(0.7)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: sageGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: sageGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 13, color: earthBrown.withOpacity(0.8))),
        ),
      ],
    );
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: vintageCream,
        body: Center(child: CircularProgressIndicator(color: sageGreen)),
      );
    }

    return Scaffold(
      backgroundColor: vintageCream,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: sageGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Switch Dashboard',
              onPressed: _showSwitchDashboardDialog,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [sageGreen, Color(0xFF90A08E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
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
                          backgroundColor: vintageCream,
                          backgroundImage: (_profilePicUrl != null && _profilePicUrl!.isNotEmpty)
                              ? NetworkImage(_profilePicUrl!)
                              : null,
                          child: (_profilePicUrl == null || _profilePicUrl!.isEmpty)
                              ? Text(
                                  user?.displayName?.substring(0, 1).toUpperCase() ?? 
                                  user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                                  style: const TextStyle(fontSize: 40, color: earthBrown, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ),
                      if (_isAdmin)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                            child: const Icon(Icons.admin_panel_settings_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/editProfile'),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: dustyRose,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'User',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'No email',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                  ),
                  if (_currentUserType != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: vintageCream.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _currentUserType!.toUpperCase(),
                        style: const TextStyle(color: earthBrown, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildSection('App Settings', Icons.tune_rounded, [
              _buildSwitchTile(
                icon: Icons.notifications_active_rounded,
                title: 'Push Notifications',
                subtitle: 'Receive hazard alerts',
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                  _saveSetting('notifications', value);
                },
              ),
              _buildSwitchTile(
                icon: Icons.volume_up_rounded,
                title: 'Voice Alerts',
                subtitle: 'Audio warnings while driving',
                value: _soundAlertsEnabled,
                onChanged: (value) {
                  setState(() => _soundAlertsEnabled = value);
                  _saveSetting('soundAlerts', value);
                },
              ),
              _buildSwitchTile(
                icon: Icons.sensors_rounded,
                title: 'Auto-Detection',
                subtitle: 'Sensor fusion hazard detection',
                value: _autoDetectionEnabled,
                onChanged: (value) {
                  setState(() => _autoDetectionEnabled = value);
                  _saveSetting('autoDetection', value);
                },
              ),
            ]),

            _buildSection('Map Preferences', Icons.map_rounded, [
              _buildListTile(
                icon: Icons.layers_rounded,
                title: 'Map Type',
                subtitle: _selectedMapType,
                onTap: _showMapTypeDialog,
              ),
            ]),

            _buildSection('Your Statistics', Icons.bar_chart_rounded, [
              _buildStatTile(icon: Icons.report_rounded, title: 'Manual Reports', value: _totalReports.toString()),
              _buildStatTile(icon: Icons.sensors_rounded, title: 'Auto Detections', value: _totalDetections.toString()),
              _buildStatTile(icon: Icons.directions_car_rounded, title: 'Distance', value: '${_distanceTraveled.toStringAsFixed(1)} km'),
            ]),

            _buildSection('More', Icons.more_horiz_rounded, [
              _buildListTile(icon: Icons.info_outline_rounded, title: 'About SARHA', subtitle: 'Version 1.0.0', onTap: _showAboutDialog),
              _buildListTile(icon: Icons.privacy_tip_outlined, title: 'Privacy Policy', onTap: () => _showSnackBar('Coming soon', Colors.blue)),
              _buildListTile(icon: Icons.help_outline_rounded, title: 'Help & Support', onTap: () => _showSnackBar('Coming soon', Colors.blue)),
            ]),

            const SizedBox(height: 20),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleLogout, // Correctly calling the logout handler
                  icon: const Icon(Icons.logout_rounded, size: 22),
                  label: const Text('Logout', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dustyRose,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
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

  // UI Helpers (Sections, Tiles, etc.)
  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: sageGreen, size: 24),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: earthBrown)),
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
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: sageGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: sageGreen, size: 22),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: earthBrown, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: earthBrown.withOpacity(0.6))),
        value: value,
        activeColor: dustyRose,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildListTile({required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: sageGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: sageGreen, size: 22),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: earthBrown, fontSize: 15)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: earthBrown.withOpacity(0.6))) : null,
        trailing: Icon(Icons.chevron_right_rounded, color: earthBrown.withOpacity(0.4)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatTile({required IconData icon, required String title, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightTan.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: sageGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: sageGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: sageGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: earthBrown))),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dustyRose)),
        ],
      ),
    );
  }
}