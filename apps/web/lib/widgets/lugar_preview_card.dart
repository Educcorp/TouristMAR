import 'package:flutter/material.dart';

import '../models/lugar.dart';
import '../services/recorridos_service.dart';
import '../theme/app_theme.dart';
import 'cover_image.dart';

/// Resumen de un lugar al seleccionarlo en el mapa (o en la lista de
/// resultados), al estilo de la ficha de Google Maps: portada con acceso al
/// recorrido 360°, categoría, calificación, experiencias y los botones
/// "Cómo llegar" / "Ver ficha".
class LugarPreviewCard extends StatelessWidget {
  final Lugar lugar;
  final VoidCallback? onVerFicha;
  final VoidCallback? onCerrar;
  final bool compacta;

  /// Recorrido 360° del lugar (null = no tiene). Con [onVer360] se muestra
  /// el acceso sobre la portada, como la miniatura de Street View.
  final RecorridoPublico? recorrido360;
  final VoidCallback? onVer360;

  /// Ruta en Google Maps; solo se ofrece si el lugar tiene pin.
  final VoidCallback? onComoLlegar;

  const LugarPreviewCard({
    super.key,
    required this.lugar,
    this.onVerFicha,
    this.onCerrar,
    this.compacta = false,
    this.recorrido360,
    this.onVer360,
    this.onComoLlegar,
  });

  bool get _con360 => recorrido360 != null && onVer360 != null;

  @override
  Widget build(BuildContext context) {
    final cat = lugar.categoria;
    final imagen = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.buttonLg),
      child: SizedBox(
        width: compacta ? 84 : double.infinity,
        height: compacta ? 84 : 150,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverImage(source: lugar.portada),
            if (_con360)
              Positioned(
                left: compacta ? 4 : 8,
                bottom: compacta ? 4 : 8,
                child: _Acceso360(recorrido: recorrido360!, compacto: compacta, onTap: onVer360!),
              ),
          ],
        ),
      ),
    );

    final datos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(cat.icon, size: 12, color: cat.color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                lugar.categoriaTexto.isEmpty ? cat.etiqueta : lugar.categoriaTexto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cat.color, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(lugar.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.star, size: 13, color: Colors.amber),
            const SizedBox(width: 3),
            Text(lugar.rating.toStringAsFixed(1),
                style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
            Text(' (${lugar.totalResenas})', style: AppTypography.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ExperienciasMiniBadges(lugar: lugar),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.panelNavySoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compacta)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                imagen,
                const SizedBox(width: AppSpacing.md),
                Expanded(child: datos),
                if (onCerrar != null)
                  InkWell(
                    onTap: onCerrar,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: AppColors.slate400),
                    ),
                  ),
              ],
            )
          else ...[
            Stack(
              children: [
                imagen,
                if (onCerrar != null)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onCerrar,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            datos,
          ],
          if (onVerFicha != null || onComoLlegar != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (onComoLlegar != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onComoLlegar,
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Cómo llegar', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandTeal,
                        side: BorderSide(color: AppColors.brandTeal),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                      ),
                    ),
                  ),
                if (onComoLlegar != null && onVerFicha != null) const SizedBox(width: AppSpacing.sm),
                if (onVerFicha != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: onVerFicha,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandTeal,
                        foregroundColor: AppColors.panelNavy,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                      ),
                      child: Text(onComoLlegar != null ? 'Ver ficha' : 'Ver ficha del lugar',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Acceso al recorrido 360° sobre la portada: miniatura redonda del primer
/// escenario y "360°", como el acceso a Street View en Google Maps.
class _Acceso360 extends StatelessWidget {
  final RecorridoPublico recorrido;
  final bool compacto;
  final VoidCallback onTap;

  const _Acceso360({required this.recorrido, required this.compacto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final miniatura = Container(
      width: compacto ? 26 : 34,
      height: compacto ? 26 : 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        color: AppColors.oceanBlue,
      ),
      clipBehavior: Clip.antiAlias,
      child: recorrido.urlPortada.isEmpty
          ? const Icon(Icons.threesixty, size: 16, color: Colors.white)
          : Image.network(recorrido.urlPortada, fit: BoxFit.cover),
    );
    return Tooltip(
      message: 'Recorrer en 360°',
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(3, 3, compacto ? 3 : 12, 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                miniatura,
                if (!compacto) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.threesixty, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  const Text('Ver en 360°', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tres íconos pequeños (marcador, ubicación, 360°): encendidos si el lugar
/// ofrece esa experiencia.
class ExperienciasMiniBadges extends StatelessWidget {
  final Lugar lugar;
  const ExperienciasMiniBadges({super.key, required this.lugar});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tipo in ExperienciaTipo.values)
          Builder(builder: (context) {
            final info = ExperienciaInfo.of(tipo);
            final activa = lugar.tiene(tipo);
            final color = activa ? info.color : AppColors.slate500;
            return Tooltip(
              message: activa ? info.titulo : '${info.tituloCorto}: no disponible',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: activa ? color.withValues(alpha: 0.12) : AppColors.overlay(0.04),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: activa ? color.withValues(alpha: 0.35) : AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(info.icon, size: 11, color: color),
                    const SizedBox(width: 3),
                    Text(info.tituloCorto,
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600,
                            decoration: activa ? null : TextDecoration.lineThrough)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
