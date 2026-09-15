import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';

/// Reconstruye `builder(context)` cada vez que cambia [ThemeController.mode].
///
/// `AppColors` son getters estáticos (no pasan por `Theme.of(context)`), así
/// que un widget ya construido no se entera solo por cambiar el modo — hace
/// falta forzar su `build()` explícitamente. Antes esto se resolvía poniendo
/// `key: ValueKey(mode)` en el `MaterialApp` raíz (ver `main.dart`), lo que
/// destruía y reconstruía TODO el árbol, Navigator incluido — de ahí el
/// parpadeo a la pantalla de login al alternar el tema.
///
/// La solución correcta es que cada pantalla independiente (cada página
/// empujada con `Navigator.push`, y cada shell) se reconstruya a sí misma
/// envolviendo su contenido en esto, sin tocar el Navigator ni perder la
/// sesión/ruta actual. Los widgets internos con clave estable (como
/// `ValueKey(_selectedId)` en el panel de empresa) conservan su State normal
/// — solo se refresca lo que de verdad depende del color.
class ThemedBuilder extends StatelessWidget {
  final WidgetBuilder builder;

  const ThemedBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, _, __) => builder(context),
    );
  }
}
