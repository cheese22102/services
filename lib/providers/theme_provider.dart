import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/scheduler.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  static const String _prefsKey = 'themePreference';

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_prefsKey) ?? 'system';
    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.toString() == 'ThemeMode.$savedMode',
      orElse: () => ThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.toString().split('.').last);
    notifyListeners();
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF1A5F7A), // Deep blue-teal
      scaffoldBackgroundColor: const Color(0xFFF8F9FA), // Light gray background
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF1A5F7A), // Deep blue-teal
        secondary: const Color(0xFFFF8C42), // Warm orange
        surface: Colors.white,
        background: const Color(0xFFF8F9FA), // Light gray background
      ),
    ).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1A5F7A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(const Color(0xFF1A5F7A)),
          foregroundColor: MaterialStateProperty.all(Colors.white),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF62B6CB), // Lighter blue-teal for dark mode
      scaffoldBackgroundColor: const Color(0xFF121212), // Dark background
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF62B6CB), // Lighter blue-teal
        secondary: const Color(0xFFFFB347), // Lighter orange for dark mode
        surface: const Color(0xFF1E1E1E), // Dark surface
        background: const Color(0xFF121212), // Dark background
      ),
    ).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(const Color(0xFF62B6CB)),
          foregroundColor: MaterialStateProperty.all(Colors.black),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}