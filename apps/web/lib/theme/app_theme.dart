import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_controller.dart';

/// Paleta "Pangas pintadas": las lanchas de pescadores de Manzanillo. Casco
/// claro, tinta marina, y cuatro esmaltes planos que pintan la franja de
/// flotación según el tipo de lugar. Seis tintas y ninguna más: nada de
/// degradados, vidrio ni sombras difusas.
///
/// Los colores son getters (no `const`) que resuelven al valor claro u oscuro
/// según [ThemeController.isDark]. El modo claro es el de diario: el turista
/// usa la app en la calle, al sol. Los nombres viejos (`panelNavy`,
/// `brandTeal`…) se conservan para no tocar cada pantalla: ahora apuntan a
/// las tintas del casco.
class AppColors {
  static bool get _dark => ThemeController.isDark;

  // ── Tintas base ──────────────────────────────────────────────────────────
  /// Casco: el fondo de la app.
  static Color get casco => _dark ? const Color(0xFF071C26) : const Color(0xFFF4F7F6);

  /// Cubierta: superficies elevadas (tarjetas, hojas, menús).
  static Color get cubierta => _dark ? const Color(0xFF0D2A37) : const Color(0xFFFFFFFF);

  /// Tinta marina: texto principal y el riel de navegación.
  static Color get tinta => _dark ? const Color(0xFFEAF1EF) : const Color(0xFF0B2A3A);

  /// Riel de navegación (barra inferior, menú lateral): siempre tinta marina.
  static const riel = Color(0xFF0B2A3A);
  static const sobreRiel = Color(0xFFF4F7F6);
  static const sobreRielSuave = Color(0xFFA9C0C7);

  // ── Esmaltes (franjas de categoría) ─────────────────────────────────────
  // El esmalte puro se usa como relleno (franjas, pins, fichas) con texto en
  // tinta encima; para texto o iconos sobre el casco se usa la versión
  // `*Texto`, que pasa contraste 4.5:1.
  static const turquesa = Color(0xFF00A6A6);
  static const amarillo = Color(0xFFF2B705);
  static const azul = Color(0xFF1F6FB2);
  static const rojo = Color(0xFFC8432B);

  static Color get turquesaTexto => _dark ? const Color(0xFF3CCFCB) : const Color(0xFF00706F);
  static Color get amarilloTexto => _dark ? const Color(0xFFF2C94C) : const Color(0xFF805C00);
  static Color get azulTexto => _dark ? const Color(0xFF7DB3E6) : const Color(0xFF1A5E98);
  static Color get rojoTexto => _dark ? const Color(0xFFF08A73) : const Color(0xFFAE3520);

  // ── Nombres heredados (mapean al sistema nuevo) ─────────────────────────
  static Color get brandTeal => turquesaTexto;
  static const brandTealDark = Color(0xFF00706F);

  static Color get panelNavy => casco;
  static Color get panelNavySoft => cubierta;

  static Color get slate300 => _dark ? const Color(0xFFC3D3D8) : const Color(0xFF2E4B59);
  static Color get slate400 => _dark ? const Color(0xFF9DB4BC) : const Color(0xFF46636F);
  static Color get slate500 => _dark ? const Color(0xFF86A0A9) : const Color(0xFF587480);

  static Color get errorRed => rojoTexto;
  static Color get orange => rojoTexto;
  static Color get amber => amarilloTexto;

  // Un solo producto, tres roles: empresa y admin ya no tienen su propio
  // color de acento; el rol se marca con su insignia, no con otra paleta.
  static Color get businessOrange => turquesaTexto;
  static const businessOrangeDark = Color(0xFF00706F);
  static Color get adminViolet => turquesaTexto;
  static const adminVioletDark = Color(0xFF00706F);

  static Color get bgDeep => casco;
  static Color get surface => cubierta;
  static Color get surfaceAlt => _dark ? const Color(0xFF123444) : const Color(0xFFE9F0EE);
  static Color get borderSubtle => _dark ? const Color(0xFF1F4656) : const Color(0xFFD2DDDA);

  static Color get oceanBlue => azulTexto;
  static Color get emerald => _dark ? const Color(0xFF5BD39A) : const Color(0xFF1B7A4B);

  /// Scrim fijo para texto blanco sobre fotos (no cambia con el tema).
  static const scrimDark = Color(0xFF0B2A3A);

  static Color get textPrimary => tinta;
  static Color get textSecondary => slate300;

  /// Bordes, fondos sutiles y hover sobre el casco.
  static Color overlay(double opacity) =>
      _dark ? Colors.white.withValues(alpha: opacity) : const Color(0xFF0B2A3A).withValues(alpha: opacity);
}

/// Escala de espaciado 4/8/12/16/24/32/48/64.
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

/// Radios: el casco de una panga es redondeado pero firme; nada de píldoras
/// blandas salvo en chips y botones de filtro.
class AppRadius {
  AppRadius._();

  static const button = 10.0;
  static const buttonLg = 12.0;
  static const card = 14.0;
  static const cardLg = 18.0;
  static const hero = 20.0;
}

/// Alto de la franja de flotación que separa la foto de los datos.
const kFranja = 6.0;

/// Jerarquía tipográfica: Barlow (grotesca de señalética, legible al sol) para
/// toda la interfaz, Barlow Semi Condensed para títulos, y la plantilla de la
/// matrícula (Big Shoulders Stencil) solo para códigos y cifras cortas.
class AppTypography {
  AppTypography._();

  static TextStyle get display => GoogleFonts.barlowSemiCondensed(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.05,
        letterSpacing: -0.4,
      );

  static TextStyle get h1 => GoogleFonts.barlowSemiCondensed(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.1,
        letterSpacing: -0.2,
      );

  static TextStyle get h2 => GoogleFonts.barlowSemiCondensed(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.15,
      );

  static TextStyle get h3 => GoogleFonts.barlow(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.barlow(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.slate300,
        height: 1.45,
      );

  static TextStyle get bodySmall => GoogleFonts.barlow(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.slate400,
      );

  static TextStyle get caption => GoogleFonts.barlow(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.slate500,
      );

  /// Cifras de tablero (métricas, distancias): condensada, gruesa y con
  /// números tabulares para que las columnas no bailen.
  static TextStyle cifra({double size = 28, Color? color}) => GoogleFonts.barlowSemiCondensed(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.05,
        color: color ?? AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Matrícula pintada con plantilla: solo códigos ("MZ-014") e insignias.
  /// No para cifras sueltas: el 0 en plantilla se lee como "()".
  static TextStyle matricula({double size = 15, Color? color}) => GoogleFonts.bigShouldersStencilText(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: color ?? AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

class AppTheme {
  /// El `ThemeData` del modo actual de [ThemeController]. `main.dart` lo
  /// reconstruye cada vez que cambia el modo.
  static ThemeData get current {
    final dark = ThemeController.isDark;
    final scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: AppColors.tinta,
      onPrimary: AppColors.casco,
      secondary: AppColors.turquesaTexto,
      onSecondary: AppColors.casco,
      tertiary: AppColors.amarillo,
      onTertiary: AppColors.riel,
      error: AppColors.rojoTexto,
      onError: Colors.white,
      surface: AppColors.cubierta,
      onSurface: AppColors.tinta,
      onSurfaceVariant: AppColors.slate400,
      outline: AppColors.borderSubtle,
      outlineVariant: AppColors.borderSubtle,
      surfaceContainerHighest: AppColors.surfaceAlt,
      inverseSurface: AppColors.riel,
      onInverseSurface: AppColors.sobreRiel,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: AppColors.casco);
    final textTheme = GoogleFonts.barlowTextTheme(base.textTheme).apply(
      bodyColor: AppColors.tinta,
      displayColor: AppColors.tinta,
    );
    final redondeo = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button));
    const botonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    final botonTexto = GoogleFonts.barlow(fontSize: 16, fontWeight: FontWeight.w600);

    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineLarge: AppTypography.display,
        headlineMedium: AppTypography.h1,
        headlineSmall: AppTypography.h2,
        titleLarge: AppTypography.h2,
        titleMedium: AppTypography.h3,
        bodyLarge: AppTypography.body.copyWith(color: AppColors.tinta),
        bodyMedium: GoogleFonts.barlow(fontSize: 15, color: AppColors.tinta, height: 1.4),
        bodySmall: AppTypography.bodySmall,
        labelLarge: botonTexto,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.tinta,
        selectionColor: AppColors.turquesa.withValues(alpha: 0.35),
        selectionHandleColor: AppColors.turquesa,
      ),
      iconTheme: IconThemeData(color: AppColors.tinta, size: 22),
      dividerTheme: DividerThemeData(color: AppColors.borderSubtle, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.tinta,
          foregroundColor: AppColors.casco,
          minimumSize: const Size(48, 48),
          padding: botonPadding,
          textStyle: botonTexto,
          shape: redondeo,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.tinta,
          foregroundColor: AppColors.casco,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: botonPadding,
          textStyle: botonTexto,
          shape: redondeo,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.tinta,
          side: BorderSide(color: AppColors.tinta, width: 1.5),
          minimumSize: const Size(48, 48),
          padding: botonPadding,
          textStyle: botonTexto,
          shape: redondeo,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.turquesaTexto,
          minimumSize: const Size(48, 44),
          textStyle: botonTexto,
          shape: redondeo,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cubierta,
        hintStyle: GoogleFonts.barlow(fontSize: 16, color: AppColors.slate500),
        labelStyle: GoogleFonts.barlow(fontSize: 15, color: AppColors.slate400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: AppColors.tinta, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: AppColors.rojoTexto, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cubierta,
        selectedColor: AppColors.tinta,
        labelStyle: GoogleFonts.barlow(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.tinta),
        secondaryLabelStyle: GoogleFonts.barlow(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.casco),
        side: BorderSide(color: AppColors.borderSubtle),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cubierta,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cubierta,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.cardLg)),
        titleTextStyle: AppTypography.h2,
        contentTextStyle: AppTypography.body,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.cubierta,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.cardLg))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.riel,
        contentTextStyle: GoogleFonts.barlow(fontSize: 15, color: AppColors.sobreRiel),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.riel, borderRadius: BorderRadius.circular(6)),
        textStyle: GoogleFonts.barlow(fontSize: 13, color: AppColors.sobreRiel),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.riel,
        indicatorColor: AppColors.turquesa,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => GoogleFonts.barlow(
            fontSize: 13,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? AppColors.sobreRiel : AppColors.sobreRielSuave,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? AppColors.riel : AppColors.sobreRielSuave,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.tinta, linearTrackColor: AppColors.surfaceAlt),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.casco : AppColors.slate400),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.turquesaTexto : AppColors.surfaceAlt),
      ),
      focusColor: AppColors.turquesa.withValues(alpha: 0.25),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
