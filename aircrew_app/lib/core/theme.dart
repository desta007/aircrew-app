import 'package:flutter/material.dart';

/// AirCrew brand palette — derived from the flow infographics
/// (navy blue base, red accent, gold highlight).
class AirColors {
  static const navy = Color(0xFF0B1F4D);
  static const navyDark = Color(0xFF081537);
  static const navyLight = Color(0xFF16327A);
  static const blue = Color(0xFF1E5BE6);
  static const red = Color(0xFFE11B22);
  static const redDark = Color(0xFFB3141A);
  static const gold = Color(0xFFF4B740);
  static const green = Color(0xFF17A54A);
  static const greenLight = Color(0xFFE6F6EC);
  static const surface = Color(0xFFF4F6FB);
  static const card = Colors.white;
  static const line = Color(0xFFE3E8F1);
  static const textDim = Color(0xFF6B7590);
  static const text = Color(0xFF17213B);

  // per-area colors used across apps & dashboard
  static const areaColors = <String, Color>{
    'Utara': Color(0xFF2E63C4),
    'Timur': Color(0xFF17A54A),
    'Pusat': Color(0xFFE07B1A),
    'Barat': Color(0xFF7A3EC4),
    'Selatan': Color(0xFFE11B22),
    'Tangerang': Color(0xFFC2185B),
  };
}

class AirTheme {
  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: AirColors.surface,
      colorScheme: const ColorScheme.light(
        primary: AirColors.navy,
        secondary: AirColors.red,
        surface: Colors.white,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AirColors.text,
        displayColor: AirColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AirColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AirColors.line),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AirColors.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AirColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AirColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AirColors.navy, width: 1.6),
        ),
      ),
    );
  }
}
