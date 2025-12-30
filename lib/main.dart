import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

// SCREENS
import 'screen/splash_screen.dart';
import 'screen/user_type_selection_screen.dart';
import 'screen/login_screen.dart';
import 'screen/registration_screen.dart';
import 'screen/home_screen.dart';
import 'screen/settings_screen.dart';
import 'screen/edit_profilescreen.dart';
import 'screen/responder_dashboard_screen.dart';
import 'screen/responder_loginscreen.dart';
import 'screen/responder_signupscreen.dart';
import 'screen/admin_panelscreen.dart';
import 'screen/manual_reportscreen.dart';
import 'screen/map_detectionscreen.dart';
import 'screen/AR_hazardscreen.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Check Stay Logged In Status
  final prefs = await SharedPreferences.getInstance();
  final bool stayLoggedIn = prefs.getBool('stay_logged_in') ?? false;
  final String? userType = prefs.getString('user_type'); // 'driver' or 'responder'

if (stayLoggedIn) {
  final now = DateTime.now().millisecondsSinceEpoch;
  await prefs.setInt('loginTimestamp', now);
  print('✅ Saved login state: stay=$stayLoggedIn, timestamp=$now');
}

  runApp(SarhaApp(
    initialRoute: stayLoggedIn ? _getHomeRoute(userType) : '/',
  ));
}

String _getHomeRoute(String? type) {
  if (type == 'responder') return '/responderDashboard';
  return '/driverDashboard';
}

class SarhaApp extends StatelessWidget {
  final String initialRoute;
  const SarhaApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SARHA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3C959B),
          primary: const Color(0xFF3C959B),
          secondary: const Color(0xFFDADE5B),
          tertiary: const Color(0xFFF7AD97),
          surface: const Color(0xFFF5F5F5),
          brightness: Brightness.light,
        ),
      ),
      // If we are auto-logging in, we go straight to dashboard, otherwise Splash
      initialRoute: initialRoute == '/' ? null : initialRoute,
      home: initialRoute == '/' ? const SplashScreen() : null,

      routes: {
        '/authGate': (_) => const AuthGate(),
        '/userTypeSelection': (_) => const UserTypeSelectionScreen(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegistrationScreen(),
        '/driverLogin': (_) => const LoginScreen(),
        '/responderLogin': (_) => const ResponderLoginScreen(),
        '/responderSignup': (_) => const ResponderSignupScreen(),
        '/driverDashboard': (_) => const HomeScreen(),
        '/responderDashboard': (_) => const ResponderDashboardScreen(),
        '/adminPanel': (_) => const AdminPanelScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/editProfile': (_) => const EditProfileScreen(),
        '/manualReport': (_) => const ManualReportScreen(),
        '/mapDetection': (_) => const MapDetectionScreen(),
        '/arView': (_) => const ARHazardScreen(),
      },
    );
  }
}