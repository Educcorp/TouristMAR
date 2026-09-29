import 'package:flutter/material.dart';
import 'package:touristmar_web/theme/app_theme.dart';

class OpcionExperiencia {
  final String valor;
  final String titulo;
  final String? detalle;
  final String? imagenUrl;

  const OpcionExperiencia({required this.valor, required this.titulo, this.detalle, this.imagenUrl});
}

/// Hoja inferior para elegir qué recorrido o qué playa abrir. Devuelve el
/// [OpcionExperiencia.valor] elegido, o `null` si el visitante la cierra.
Future<String?> mostrarSelectorExperiencia(
  BuildContext context, {
  required String titulo,
  required String subtitulo,
  required IconData icono,
  required List<OpcionExperiencia> opciones,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.panelNavySoft,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.cardLg)),
    ),
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.md, AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: AppTypography.h3),
                        const SizedBox(height: AppSpacing.xs),
                        Text(subtitulo, style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AppColors.slate400),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                itemCount: opciones.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) => _Opcion(opcion: opciones[i], icono: icono),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Opcion extends StatelessWidget {
  final OpcionExperiencia opcion;
  final IconData icono;

  const _Opcion({required this.opcion, required this.icono});

  @override
  Widget build(BuildContext context) {
    final miniatura = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: SizedBox(
        width: 56,
        height: 56,
        child: opcion.imagenUrl == null
            ? ColoredBox(
                color: AppColors.oceanBlue.withValues(alpha: 0.14),
                child: Icon(icono, color: AppColors.oceanBlue),
              )
            : Image.network(
                opcion.imagenUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(icono, color: AppColors.oceanBlue),
              ),
      ),
    );

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => Navigator.of(context).pop(opcion.valor),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              miniatura,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opcion.titulo,
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    if (opcion.detalle != null) ...[
                      const SizedBox(height: 2),
                      Text(opcion.detalle!, style: AppTypography.bodySmall),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.slate500),
            ],
          ),
        ),
      ),
    );
  }
}
