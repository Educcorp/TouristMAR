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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        // key: fuerza a reconstruir toda la app (Navigator incluido) al
        // cambiar de tema. Los colores de AppColors son globales (no pasan
        // por `Theme.of(context)`), así que las páginas ya montadas en el
        // stack de navegación no se enterarían del cambio sin esto. El
        // costo es volver a la pantalla principal — LoginForm ya restaura
        // la sesión y manda al usuario a su panel correspondiente, igual
        // que pasaría con un refresh normal del navegador.
        return MaterialApp(
          key: ValueKey(mode),
          title: 'TourisMAR — Iniciar sesión',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.current,
          home: LoginPage(),
        );
      },
    );
  }
}
