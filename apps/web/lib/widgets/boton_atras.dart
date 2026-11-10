import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Flecha "atrás" de las barras superiores de los paneles: aparece en
/// cualquier sección que no sea el inicio y regresa a él.
class BotonAtras extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;

  const BotonAtras({super.key, required this.onTap, this.tooltip = 'Volver al inicio'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(Icons.arrow_back_rounded, color: AppColors.tinta),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.overlay(0.05),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

/// Hace que el botón "atrás" del sistema (Android, o el gesto de regresar)
/// haga lo mismo que la flecha: si [onBack] no es null, regresa al inicio del
/// panel en vez de cerrar la app. Las secciones se cambian con `go` (sin pila
/// de pantallas), así que sin esto "atrás" sacaba de la app desde cualquier
/// pestaña. En el inicio ([onBack] null) se deja salir normalmente.
class AtrasDelSistema extends StatelessWidget {
  final VoidCallback? onBack;
  final Widget child;

  const AtrasDelSistema({super.key, required this.onBack, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack?.call();
      },
      child: child,
    );
  }
}
