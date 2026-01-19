// theme_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  // Color palettes
  static const _lightPalette = {
    'primary': Color(0xFFA7B5F4), // softLavender
    'secondary': Color(0xFFFF9B85), // coral
    'background': Color(0xFFFAF8F5), // cream
    'text': Color(0xFF4A4063), // deepPurple
    'accent': Color(0xFFD1D5F7), // lightPurple
  };

  static const _darkPalette = {
    'primary': Color(0xFF7B8EC9), // Darker lavender
    'secondary': Color(0xFFE68A70), // Darker coral
    'background': Color(0xFF1A1A1A), // Dark background
    'text': Color(0xFFE0E0E0), // Light text
    'accent': Color(0xFF3A3A4A), // Dark accent
  };

  // Get current theme mode
  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('darkMode') ?? false;
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // Set theme mode
  Future<void> setThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', isDark);
  }

  // Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: _lightPalette['primary']!,
        secondary: _lightPalette['secondary']!,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: _lightPalette['background'],
      appBarTheme: AppBarTheme(
        backgroundColor: _lightPalette['primary'],
        foregroundColor: _lightPalette['text'],
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPalette['secondary'],
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _darkPalette['primary']!,
        secondary: _darkPalette['secondary']!,
        surface: _darkPalette['accent']!,
      ),
      scaffoldBackgroundColor: _darkPalette['background'],
      appBarTheme: AppBarTheme(
        backgroundColor: _darkPalette['accent'],
        foregroundColor: _darkPalette['text'],
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: _darkPalette['accent'],
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPalette['secondary'],
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// Update main.dart to use themes:
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
    final mode = await ThemeService().getThemeMode();
    setState(() => _themeMode = mode);
  }

  void _toggleTheme(bool isDark) async {
    await ThemeService().setThemeMode(isDark);
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SARHA',
      theme: ThemeService.lightTheme,
      darkTheme: ThemeService.darkTheme,
      themeMode: _themeMode,
      // ... rest of your app
    );
  }
}

// Add dark mode toggle to settings screen:
Widget _buildDarkModeToggle(BuildContext context) {
  return SwitchListTile(
    title: const Text('Dark Mode'),
    subtitle: const Text('Switch between light and dark theme'),
    value: Theme.of(context).brightness == Brightness.dark,
    onChanged: (value) {
      // Call _toggleTheme from parent widget
      ThemeService().setThemeMode(value);
      // Restart app or use provider to update theme
    },
  );
}