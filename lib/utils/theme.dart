import 'package:flutter/material.dart';

class AppThemes {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: const Color(0xFF2B5CE6),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFF2B5CE6),
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2B5CE6),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      primaryColor: const Color(0xFF2B5CE6),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFF1E1E1E),
      ),
    );
  }
}
