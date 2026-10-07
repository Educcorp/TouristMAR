import 'package:flutter/material.dart';

import '../models/lugar.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import 'ruta_lugar_page.dart';
import '../widgets/cover_image.dart';
import '../widgets/experiencias/experiencias_lugar.dart';
import '../widgets/favorito_button.dart';
import '../widgets/mapa/mapa_lugares.dart';
import '../widgets/themed_builder.dart';

/// Ficha pública de un lugar (lo que ve el visitante al tocar un pin del
/// mapa o una tarjeta): portada, datos, las tres experiencias inmersivas y
/// su ubicación.
class LugarDetallePage extends StatelessWidget {
  final Lugar lugar;

  /// El negocio o un admin viendo la ficha como la verá un visitante.
  final bool vistaPrevia;

  const LugarDetallePage({super.key, required this.lugar, this.vistaPrevia = false});

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _build);

  Widget _build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.panelNavy,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Hero(lugar: lugar, vistaPrevia: vistaPrevia)),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final ancho = Breakpoints.isExpanded(constraints.maxWidth + 48);
                      final principal = _Principal(lugar: lugar, vistaPrevia: vistaPrevia);
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

  const _Hero({required this.lugar, required this.vistaPrevia});

  @override
  Widget build(BuildContext context) {
    final cat = lugar.categoria;
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CoverImage(source: lugar.portada),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppColors.scrimDark.withValues(alpha: 0.95), AppColors.scrimDark.withValues(alpha: 0.1)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.black.withValues(alpha: 0.4),
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
                      decoration: BoxDecoration(
                        color: AppColors.amber,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('VISTA PREVIA',
                          style: TextStyle(color: AppColors.scrimDark, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    )
                  else
                    FavoritoButton(lugar: lugar, size: 24),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: cat.color, borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(lugar.categoriaTexto.isEmpty ? cat.etiqueta : lugar.categoriaTexto,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(lugar.nombre, style: AppTypography.h1.copyWith(color: Colors.white)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(i < lugar.rating.round() ? Icons.star : Icons.star_border,
                                size: 16, color: Colors.amber),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            lugar.totalResenas == 0
                                ? 'Sin reseñas aún'
                                : '${lugar.rating.toStringAsFixed(1)} · ${lugar.totalResenas} reseñas',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
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

class _Principal extends StatelessWidget {
  final Lugar lugar;
  final bool vistaPrevia;

  const _Principal({required this.lugar, required this.vistaPrevia});

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
        Text('Valoraciones y comentarios', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            children: [
              Icon(Icons.forum_outlined, color: AppColors.slate400, size: 28),
              const SizedBox(height: AppSpacing.sm),
              Text('Las reseñas de visitantes aparecerán aquí.', style: AppTypography.body),
            ],
          ),
        ),
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
