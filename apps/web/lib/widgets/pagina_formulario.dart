import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Esqueleto de las pantallas de edición (editar perfil, editar negocio,
/// galería, sugerir lugar): "volver", título, descripción y el formulario en
/// una columna de [AppAncho.formulario]. Toda la pantalla hace scroll, no solo
/// la columna (con el cursor a los lados la rueda no hacía nada), y las cuatro
/// pantallas comparten medidas en vez de elegir cada una la suya.
class PaginaFormulario extends StatelessWidget {
  final String volver;
  final VoidCallback onVolver;
  final String titulo;
  final String? descripcion;
  final Widget child;

  const PaginaFormulario({
    super.key,
    required this.volver,
    required this.onVolver,
    required this.titulo,
    this.descripcion,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.casco,
      body: SafeArea(
        child: SizedBox.expand(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppAncho.formulario),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onVolver,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.slate300,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        label: Text(volver, style: AppTypography.boton(size: 15)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(titulo, style: AppTypography.h1),
                    if (descripcion != null) ...[
                      const SizedBox(height: 6),
                      Text(descripcion!, style: AppTypography.body),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
