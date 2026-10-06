import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Tarjeta que se expande y se oculta con una flecha. La usa "Mapa y RA" para
/// el formulario de registrar un lugar y para cada experiencia de un lugar
/// (RA por ubicación, recorrido 360°, RA con marcador): en vez de un estado
/// "falta / activo", ahí mismo se llena el formulario.
class SeccionDesplegable extends StatefulWidget {
  final IconData icon;
  final String titulo;
  final String? subtitulo;
  final Color? color;
  final bool abiertaAlInicio;
  final Widget child;

  /// Para abrirla o cerrarla desde fuera (p. ej. cerrar el formulario al guardar).
  final ValueNotifier<bool>? abierta;

  const SeccionDesplegable({
    super.key,
    required this.icon,
    required this.titulo,
    this.subtitulo,
    this.color,
    this.abiertaAlInicio = false,
    this.abierta,
    required this.child,
  });

  @override
  State<SeccionDesplegable> createState() => _SeccionDesplegableState();
}

class _SeccionDesplegableState extends State<SeccionDesplegable> {
  late final ValueNotifier<bool> _abierta = widget.abierta ?? ValueNotifier(widget.abiertaAlInicio);

  @override
  void initState() {
    super.initState();
    if (widget.abierta != null && widget.abiertaAlInicio) _abierta.value = true;
  }

  @override
  void dispose() {
    if (widget.abierta == null) _abierta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.adminViolet;
    return ValueListenableBuilder<bool>(
      valueListenable: _abierta,
      builder: (context, abierta, _) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: abierta ? color.withValues(alpha: 0.5) : AppColors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => _abierta.value = !abierta,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: Icon(widget.icon, color: color, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.titulo, style: AppTypography.h3),
                            if (widget.subtitulo != null) ...[
                              const SizedBox(height: 2),
                              Text(widget.subtitulo!, style: AppTypography.bodySmall),
                            ],
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: abierta ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down, color: AppColors.slate300),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: abierta
                    ? Container(
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderSubtle))),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: widget.child,
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}
