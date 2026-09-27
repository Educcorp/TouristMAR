import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() {
  runApp(const TouristMarApp());
}

class TouristMarApp extends StatelessWidget {
  const TouristMarApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Sin `key: ValueKey(mode)`: cada pantalla se reconstruye a sí misma con
    // `ThemedBuilder` (ver ese archivo) en vez de forzar la reconstrucción de
    // toda la app — así el Navigator y la sesión actual sobreviven al cambio
    // de tema, sin el parpadeo de vuelta al login que había antes.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'TouristMAR — Iniciar sesión',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.current,
          home: LoginPage(),
        );
      },
    );
  }
}
