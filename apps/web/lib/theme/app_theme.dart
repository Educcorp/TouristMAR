import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const brandTeal = Color(0xFF22D3EE);
  static const brandTealDark = Color(0xFF0E9AAD);
  static const panelNavy = Color(0xFF0B1220);
  static const panelNavySoft = Color(0xFF131D30);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const errorRed = Color(0xFFF87171);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandTeal,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.panelNavy,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.playfairDisplay(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
