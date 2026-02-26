import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

// Screens
import 'screen/user_type_selection_screen.dart';
import 'screen/login_screen.dart';
import 'screen/responder_loginscreen.dart';
import 'screen/registration_screen.dart';
import 'screen/home_screen.dart';
import 'screen/responder_dashboard_screen.dart';
import 'screen/edit_profilescreen.dart';
import 'screen/settings_screen.dart';
import 'screen/unified_detection_screen.dart';
import 'screen/manual_reportscreen.dart';

// Services
import 'services/notification_services.dart';
import 'services/analytics_services.dart';
import 'services/ar_services.dart';

//View
import 'view/ar_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  try {
    await NotificationService.initialize();
    print('✅ Notifications initialized');
  } catch (e) {
    print('⚠️ Notification initialization failed: $e');
  }

  try {
    await AnalyticsService().logAppOpen();
    print('📊 Analytics initialized');
  } catch (e) {
    print('⚠️ Analytics failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('darkMode') ?? false;
      setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
    } catch (e) {
      print('⚠️ Theme load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ARService(),
      child: MaterialApp(
        title: 'SARHA',
        debugShowCheckedModeBanner: false,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: _themeMode,

        // ✅ PERSISTENT LOGIN: Check auth state on every app open
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Still connecting to Firebase
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            // User is logged in
            if (snapshot.hasData && snapshot.data != null) {
              return FutureBuilder<SharedPreferences>(
                future: SharedPreferences.getInstance(),
                builder: (context, prefsSnapshot) {
                  if (!prefsSnapshot.hasData) return const _SplashScreen();

                  final userType =
                      prefsSnapshot.data!.getString('userType') ?? 'driver';

                  if (userType == 'responder') {
                    return const ResponderDashboardScreen();
                  }
                  return const HomeScreen();
                },
              );
            }

            // Not logged in - show selection screen
            return const UserTypeSelectionScreen();
          },
        ),

        routes: {
          '/userTypeSelection': (context) => const UserTypeSelectionScreen(),
          '/driverLogin': (context) => const LoginScreen(),
          '/responderLogin': (context) => const ResponderLoginScreen(),
          '/driverSignup': (context) => const RegistrationScreen(),
          '/home': (context) => const HomeScreen(),
          '/driverDashboard': (context) => const HomeScreen(),
          '/responderDashboard': (context) => const ResponderDashboardScreen(),
          '/editProfile': (context) => const EditProfileScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/unifiedDetection': (context) => const UnifiedDetectionScreen(),
          '/manualReport': (context) => ManualReportScreen(),
          '/arHazard': (context) => ARView(),
        },

        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const UserTypeSelectionScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const softLavender = Color(0xFFA7B5F4);
    const coral = Color(0xFFFF9B85);
    const cream = Color(0xFFFAF8F5);
    const deepPurple = Color(0xFF4A4063);
    const lightPurple = Color(0xFFD1D5F7);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: softLavender,
        secondary: coral,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: softLavender,
        foregroundColor: deepPurple,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: coral,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: softLavender,
          side: const BorderSide(color: softLavender, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightPurple),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: lightPurple),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: softLavender, width: 2),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const darkLavender = Color.fromARGB(255, 14, 20, 39);
    const darkCoral = Color(0xFFE68A70);
    const darkBackground = Color.fromARGB(255, 34, 22, 43);
    const darkSurface = Color(0xFF2A2A3A);
    const lightText = Color(0xFFE0E0E0);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: darkLavender,
        secondary: darkCoral,
        surface: darkSurface,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: lightText,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkCoral,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkLavender,
          side: const BorderSide(color: darkLavender, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkLavender.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkLavender.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkLavender, width: 2),
        ),
      ),
    );
  }
}

// Simple splash screen shown while checking auth state
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFAF8F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_rounded,
                size: 80, color: Color(0xFFA7B5F4)),
            SizedBox(height: 24),
            Text(
              'SARHA',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A4063),
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Smart Assist for Road Hazard Alerting',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF4A4063),
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Color(0xFFFF9B85)),
          ],
        ),
      ),
    );
  }
}
