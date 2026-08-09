import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF22C55E);

  static ThemeData _baseTheme(Brightness brightness, Color seedColor) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),
      textTheme: GoogleFonts.interTextTheme(
        isDark ? ThemeData.dark().textTheme : null,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF1E1E2E) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: seedColor, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      scaffoldBackgroundColor: isDark ? const Color(0xFF121218) : null,
    );
  }

  static ThemeData getTheme(String themeName, Brightness brightness) {
    final seedColor = _getSeedColor(themeName);
    return _baseTheme(brightness, seedColor);
  }

  static Color _getSeedColor(String themeName) {
    switch (themeName.toLowerCase()) {
      case 'ocean':
        return const Color(0xFF0EA5E9);
      case 'forest':
        return const Color(0xFF22C55E);
      case 'purple':
      case 'galaxy':
        return const Color(0xFF8B5CF6);
      case 'sunset':
        return const Color(0xFFF97316);
      case 'midnight':
        return const Color(0xFF1E1B4B);
      case 'autumn':
        return const Color(0xFFEA580C);
      default:
        return primaryColor;
    }
  }

  static ThemeData getThemeFromSeed(Color seedColor, Brightness brightness) {
    return _baseTheme(brightness, seedColor);
  }

  static Brightness getBrightness(String themeName) {
    switch (themeName.toLowerCase()) {
      case 'dark':
      case 'midnight':
        return Brightness.dark;
      default:
        return Brightness.light;
    }
  }

  static List<String> get availableThemes => [
    'Default',
    'Midnight',
    'Forest',
    'Sunset',
    'Ocean',
    'Autumn',
    'Galaxy',
  ];

  static ThemeData get lightTheme => getTheme('default', Brightness.light);
  static ThemeData get darkTheme => getTheme('default', Brightness.dark);
}
