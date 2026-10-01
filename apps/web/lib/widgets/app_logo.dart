import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';

/// Logo de TouristMAR (palmera en círculo). Usa la versión azul brillante
/// sobre fondos oscuros y la azul marino sobre fondos claros. [sobreFoto]
/// fuerza la versión brillante, para cuando va encima de una imagen con
/// degradado oscuro sin importar el tema.
class AppLogo extends StatelessWidget {
  final double size;
  final bool sobreFoto;

  // Sin `const` a propósito: una instancia const no se reconstruye, y el
  // logo tiene que cambiar de versión cuando cambia ThemeController.
  // ignore: prefer_const_constructors_in_immutables
  AppLogo({super.key, this.size = 32, this.sobreFoto = false});

  @override
  Widget build(BuildContext context) {
    final claro = sobreFoto || ThemeController.isDark;
    return Image.asset(
      claro ? 'assets/images/logo_light.png' : 'assets/images/logo_dark.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'TouristMAR',
    );
  }
}
