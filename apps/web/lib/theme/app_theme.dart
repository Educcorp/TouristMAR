import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_controller.dart';

/// Todos los colores de la app viven aquí como getters (no `const`) que
/// resuelven al valor claro u oscuro según [ThemeController.isDark]. Se leen
/// igual que antes (`AppColors.panelNavy`, sin pasar `context`), pero ahora
/// responden al toggle de tema porque `main.dart` reconstruye la app entera
/// cuando `ThemeController.mode` cambia.
class AppColors {
  static bool get _dark => ThemeController.isDark;

  static Color get brandTeal => _dark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490);
  static const brandTealDark = Color(0xFF0E9AAD);

  static Color get panelNavy => _dark ? const Color(0xFF0B1220) : const Color(0xFFF7F8FA);
  static Color get panelNavySoft => _dark ? const Color(0xFF131D30) : const Color(0xFFEBEFF4);

  static Color get slate300 => _dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  static Color get slate400 => _dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get slate500 => _dark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  static Color get errorRed => _dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  static Color get orange => _dark ? const Color(0xFFFB923C) : const Color(0xFFC2410C);
  static Color get amber => _dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

  // Segundo perfil de marca: panel de empresa (naranja en vez de teal).
  static Color get businessOrange => _dark ? const Color(0xFFF97316) : const Color(0xFFC2410C);
  static const businessOrangeDark = Color(0xFFC2410C);

  // Tercer perfil de marca: panel de administración (violeta).
  static Color get adminViolet => _dark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  static const adminVioletDark = Color(0xFF7C3AED);

  // Tokens del panel admin. bgDeep siempre igual al fondo general; surface y
  // borderSubtle son overlays translúcidos sobre ese fondo (blanco en
  // oscuro, negro en claro) para que las tarjetas se vean parte del mismo
  // sistema que el resto de la app en ambos modos.
  static Color get bgDeep => panelNavy;
  static Color get surface => _dark ? const Color(0x08FFFFFF) : const Color(0x08000000);
  static Color get surfaceAlt => _dark ? const Color(0x0DFFFFFF) : const Color(0x0D000000);
  static Color get borderSubtle => _dark ? const Color(0x14FFFFFF) : const Color(0x14000000);

  static Color get oceanBlue => _dark ? const Color(0xFF3B82F6) : const Color(0xFF1D4ED8);
  static Color get emerald => _dark ? const Color(0xFF34D399) : const Color(0xFF059669);

  /// Scrim fijo (no cambia con el tema) para degradados sobre fotos: una
  /// foto necesita oscurecerse igual para que el texto en blanco encima se
  /// lea, sin importar si el resto de la app está en modo claro u oscuro.
  static const scrimDark = Color(0xFF0B1220);

  /// Equivalente theme-aware de usar `Colors.white`/`Colors.white70` suelto
  /// para texto o íconos que van directo sobre el fondo del panel (no sobre
  /// un color de acento sólido, que mantiene su propio contraste).
  static Color get textPrimary => _dark ? Colors.white : const Color(0xFF0F172A);
  static Color get textSecondary => _dark ? Colors.white70 : const Color(0xFF334155);

  /// Equivalente theme-aware de `Colors.white.withValues(alpha: x)` para bordes,
  /// fondos sutiles y estados hover sobre el fondo del panel.
  static Color overlay(double opacity) => _dark ? Colors.white.withValues(alpha: opacity) : Colors.black.withValues(alpha: opacity);
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

  static const button = 8.0;
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
        color: AppColors.textPrimary,
        height: 1.1,
      );

  static TextStyle get h1 => GoogleFonts.playfairDisplay(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.15,
      );

  static TextStyle get h2 => GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
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
  /// El `ThemeData` que corresponde al modo actual de [ThemeController]. No
  /// hay un `AppTheme.light`/`AppTheme.dark` independientes porque todos los
  /// colores de [AppColors] leen el mismo estado global — construir "el
  /// tema claro" mientras el modo activo es oscuro devolvería colores
  /// oscuros con un `Brightness.light` engañoso. `main.dart` reconstruye
  /// este getter cada vez que [ThemeController.mode] cambia.
  static ThemeData get current {
    final brightness = ThemeController.isDark ? Brightness.dark : Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandTeal,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: AppColors.panelNavy,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.playfairDisplay(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.1,
        ),
        headlineMedium: GoogleFonts.playfairDisplay(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
