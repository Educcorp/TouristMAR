import 'package:flutter/material.dart';

import '../models/lugar.dart';
import '../navegacion/sesion.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import 'ruta_lugar_page.dart';
import '../widgets/casco_lugar.dart';
import '../widgets/cover_image.dart';
import '../widgets/experiencias/experiencias_lugar.dart';
import '../widgets/favorito_button.dart';
import '../services/resenas_service.dart';
import '../widgets/mapa/mapa_lugares.dart';
import '../widgets/resenas/resenas_lugar_section.dart';
import '../widgets/themed_builder.dart';

/// Ficha pública de un lugar (lo que ve el visitante al tocar un pin del
/// mapa o una tarjeta): portada, datos, las tres experiencias inmersivas y
/// su ubicación.
class LugarDetallePage extends StatefulWidget {
  final Lugar lugar;

  /// El negocio o un admin viendo la ficha como la verá un visitante.
  final bool vistaPrevia;

  const LugarDetallePage({super.key, required this.lugar, this.vistaPrevia = false});

  @override
  State<LugarDetallePage> createState() => _LugarDetallePageState();
}

class _LugarDetallePageState extends State<LugarDetallePage> {
  Lugar get lugar => widget.lugar;
  bool get vistaPrevia => widget.vistaPrevia;

  /// Calificación real vigente (la que traen las reseñas al abrir la ficha o
  /// al publicar/editar/borrar una); mientras no cargue, la del lugar.
  ResumenResenas? _resumen;

  /// Publicar o borrar una reseña cambia "Mis reseñas" del visitante (y los
  /// contadores del menú lateral): se vuelven a traer.
  void _resenasCambiaron() {
    final user = Sesion.usuario.value;
    if (user == null || user.isAdmin || user.isNegocio) return;
    Sesion.perfilVisitante.cargarResenas();
  }

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _build);

  Widget _build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.panelNavy,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Hero(lugar: lugar, vistaPrevia: vistaPrevia, resumen: _resumen)),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final ancho = Breakpoints.isExpanded(constraints.maxWidth + 48);
                      final principal = _Principal(
                        lugar: lugar,
                        vistaPrevia: vistaPrevia,
                        onResumen: (r) => setState(() => _resumen = r),
                        onCambio: _resenasCambiaron,
                      );
                      final lateral = _Lateral(lugar: lugar);
                      if (!ancho) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [principal, const SizedBox(height: AppSpacing.xl), lateral],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: principal),
                          const SizedBox(width: AppSpacing.xl),
                          SizedBox(width: 320, child: lateral),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final Lugar lugar;
  final bool vistaPrevia;
  final ResumenResenas? resumen;

  const _Hero({required this.lugar, required this.vistaPrevia, this.resumen});

  @override
  Widget build(BuildContext context) {
    final cat = lugar.categoria;
    final rating = resumen?.promedio ?? lugar.rating;
    final totalResenas = resumen?.total ?? lugar.totalResenas;
    final esmalte = cat.esmalte;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 280,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverImage(source: lugar.portada),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Material(
                        color: AppColors.riel.withValues(alpha: 0.7),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Volver',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      if (vistaPrevia)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.amarillo, borderRadius: BorderRadius.circular(4)),
                          child: Text('VISTA PREVIA', style: AppTypography.matricula(size: 14, color: AppColors.riel)),
                        )
                      else if (lugar.esFavoritable)
                        DecoratedBox(
                          decoration: BoxDecoration(color: AppColors.riel.withValues(alpha: 0.7), shape: BoxShape.circle),
                          child: FavoritoButton(lugar: lugar, size: 24),
                        ),
                    ],
                  ),
                ),
              ),
              if (lugar.esEjemplo) const Positioned(left: 16, bottom: 14, child: EtiquetaEjemplo()),
            ],
          ),
        ),
        // La línea de flotación.
        Container(height: kFranja, color: esmalte),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(cat.icon, size: 20, color: cat.color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          lugar.categoriaTexto.isEmpty ? cat.etiqueta : lugar.categoriaTexto,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.slate300, fontSize: 15),
                        ),
                      ),
                      Text(lugar.matricula, style: AppTypography.matricula(size: 18, color: AppColors.slate400)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(lugar.nombre, style: AppTypography.display.copyWith(fontSize: 34)),
                  const SizedBox(height: 8),
                  if (totalResenas == 0)
                    Text(
                      lugar.esEjemplo ? 'Lugar de ejemplo: todavía no tiene reseñas' : 'Sin reseñas todavía',
                      style: AppTypography.bodySmall,
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 20, color: AppColors.amarillo),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1), style: AppTypography.h3.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Text(
                          '$totalResenas ${totalResenas == 1 ? 'reseña' : 'reseñas'}',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Principal extends StatelessWidget {
  final Lugar lugar;
  final bool vistaPrevia;
  final ValueChanged<ResumenResenas> onResumen;
  final VoidCallback onCambio;

  const _Principal({required this.lugar, required this.vistaPrevia, required this.onResumen, required this.onCambio});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lugar.descripcion.isNotEmpty) ...[
          Text('Acerca de', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          Text(lugar.descripcion, style: AppTypography.body.copyWith(fontSize: 15, height: 1.55)),
          const SizedBox(height: AppSpacing.xxl),
        ],
        ExperienciasLugarSection(lugar: lugar, vistaPrevia: vistaPrevia),
        const SizedBox(height: AppSpacing.xxl),
        ResenasLugarSection(lugar: lugar, vistaPrevia: vistaPrevia, onResumen: onResumen, onCambio: onCambio),
      ],
    );
  }
}

class _Lateral extends StatelessWidget {
  final Lugar lugar;

  const _Lateral({required this.lugar});

  @override
  Widget build(BuildContext context) {
    final filas = [
      if (lugar.direccion != null && lugar.direccion!.isNotEmpty) (Icons.place_outlined, lugar.direccion!),
      if (lugar.horario != null && lugar.horario!.isNotEmpty) (Icons.schedule, lugar.horario!),
      if (lugar.telefono != null && lugar.telefono!.isNotEmpty) (Icons.phone_outlined, lugar.telefono!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 200,
                child: lugar.ubicacion == null
                    ? Container(
                        color: AppColors.surfaceAlt,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off_outlined, color: AppColors.slate400),
                            const SizedBox(height: 6),
                            Text('Ubicación pendiente', style: AppTypography.bodySmall),
                          ],
                        ),
                      )
                    : MapaBase(
                        centro: lugar.ubicacion!,
                        zoom: 15,
                        interactivo: false,
                        children: [
                          if (lugar.tiene(ExperienciaTipo.arGeo))
                            capaRadio(lugar.ubicacion!, lugar.radioDesbloqueo,
                                ExperienciaInfo.of(ExperienciaTipo.arGeo).color),
                          capaLugares([lugar], seleccionadoId: lugar.id),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Información', style: AppTypography.h3),
                    const SizedBox(height: AppSpacing.md),
                    if (filas.isEmpty) Text('El negocio aún no agrega sus datos de contacto.', style: AppTypography.bodySmall),
                    for (final (icon, texto) in filas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(icon, size: 16, color: AppColors.brandTeal),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: Text(texto, style: AppTypography.body)),
                          ],
                        ),
                      ),
                    if (lugar.tiene(ExperienciaTipo.arGeo) && lugar.ubicacion != null)
                      Row(
                        children: [
                          Icon(Icons.radar, size: 16, color: ExperienciaInfo.of(ExperienciaTipo.arGeo).color),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Zona de RA: ${lugar.radioDesbloqueo.round()} m alrededor del punto',
                              style: AppTypography.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    if (lugar.ubicacion != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () => abrirRutaEnMapa(context, lugar),
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Cómo llegar', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brandTeal,
                          side: BorderSide(color: AppColors.brandTeal),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
