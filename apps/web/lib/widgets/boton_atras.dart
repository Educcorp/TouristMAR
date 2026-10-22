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
