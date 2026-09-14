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
  static const orange = Color(0xFFFB923C);
  static const amber = Color(0xFFFBBF24);

  // Segundo perfil de marca: panel de empresa (naranja en vez de teal).
  static const businessOrange = Color(0xFFF97316);
  static const businessOrangeDark = Color(0xFFC2410C);

  // Tercer perfil de marca: panel de administración (violeta).
  static const adminViolet = Color(0xFFA78BFA);
  static const adminVioletDark = Color(0xFF7C3AED);

  // Tokens del sistema de diseño "dark premium SaaS" del panel admin.
  // Reutilizan los acentos de marca de arriba donde ya existe un color
  // equivalente (adminViolet = primary, brandTeal = accent, amber = warning,
  // errorRed = danger) y solo agregan lo que faltaba.
  static const bgDeep = Color(0xFF070D1A);
  static const surface = Color(0xFF101827);
  static const surfaceAlt = Color(0xFF141D2D);
  static const borderSubtle = Color(0x14FFFFFF); // rgba(255,255,255,.08)
  static const oceanBlue = Color(0xFF3B82F6); // secondary
  static const emerald = Color(0xFF34D399); // success
}

/// Escala de espaciado 4/8/12/16/24/32/48/64 compartida por el panel admin.
class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const huge = 64.0;
}

/// Radios de borde consistentes: nunca elegir un valor fuera de esta lista.
class AppRadius {
  AppRadius._();

  static const button = 10.0;
  static const buttonLg = 12.0;
  static const card = 16.0;
  static const cardLg = 20.0;
  static const hero = 24.0;
}

/// Jerarquía tipográfica del panel admin: serif editorial para lo destacado,
/// sans-serif (Inter) para el resto de la interfaz.
class AppTypography {
  AppTypography._();

  static TextStyle get display => GoogleFonts.playfairDisplay(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        height: 1.1,
      );

  static TextStyle get h1 => GoogleFonts.playfairDisplay(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.15,
      );

  static TextStyle get h2 => GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.slate300,
        height: 1.4,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.slate400,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.slate500,
        letterSpacing: 0.4,
      );
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
