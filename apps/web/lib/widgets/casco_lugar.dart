import 'package:flutter/material.dart';

import '../models/lugar.dart';
import '../theme/app_theme.dart';
import 'cover_image.dart';
import 'favorito_button.dart';

/// Un lugar pintado como panga: la foto va arriba de la línea de flotación,
/// la franja de esmalte dice qué tipo de lugar es, y debajo van el nombre, la
/// distancia y la matrícula. Es la pieza con la que se arman el inicio, los
/// favoritos y las listas del mapa.
class CascoLugar extends StatelessWidget {
  final Lugar lugar;
  final VoidCallback onTap;

  /// Metros desde el visitante; `null` cuando no compartió su ubicación.
  final double? distanciaMetros;

  const CascoLugar({super.key, required this.lugar, required this.onTap, this.distanciaMetros});

  @override
  Widget build(BuildContext context) {
    final categoria = lugar.categoria;
    return Semantics(
      button: true,
      label: '${lugar.nombre}, ${categoria.etiqueta}${distanciaMetros != null ? ', a ${textoDistancia(distanciaMetros!)}' : ''}',
      child: Material(
        color: AppColors.cubierta,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverImage(source: lugar.portada),
                    if (lugar.esEjemplo)
                      const Positioned(left: 10, top: 10, child: EtiquetaEjemplo()),
                    if (lugar.esFavoritable)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: AppColors.riel.withValues(alpha: 0.55), shape: BoxShape.circle),
                          child: FavoritoButton(lugar: lugar, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
              // La línea de flotación.
              Container(height: kFranja, color: categoria.esmalte),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            lugar.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.h3.copyWith(fontSize: 18, fontWeight: FontWeight.w700, height: 1.2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(lugar.matricula, style: AppTypography.matricula(size: 15, color: AppColors.slate400)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(categoria.icon, size: 18, color: categoria.color),
                        const SizedBox(width: 6),
                        Text(categoria.etiqueta, style: AppTypography.bodySmall.copyWith(color: AppColors.slate300)),
                        if (lugar.tieneExperiencias) ...[
                          const SizedBox(width: 10),
                          for (final tipo in ExperienciaTipo.values.where(lugar.tiene))
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Tooltip(
                                message: ExperienciaInfo.of(tipo).titulo,
                                child: Icon(ExperienciaInfo.of(tipo).icon, size: 18, color: ExperienciaInfo.of(tipo).color),
                              ),
                            ),
                        ],
                        const Spacer(),
                        if (lugar.totalResenas > 0) ...[
                          const Icon(Icons.star_rounded, size: 18, color: AppColors.amarillo),
                          const SizedBox(width: 2),
                          Text(
                            lugar.rating.toStringAsFixed(1),
                            style: AppTypography.bodySmall.copyWith(color: AppColors.tinta, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                    if (distanciaMetros != null) ...[
                      const SizedBox(height: 10),
                      BarraDistancia(metros: distanciaMetros!, esmalte: categoria.esmalte),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "850 m" o "2.4 km".
String textoDistancia(double metros) =>
    metros < 1000 ? '${(metros / 10).round() * 10} m' : '${(metros / 1000).toStringAsFixed(1)} km';

/// Minutos caminando a 4.8 km/h.
int minutosCaminando(double metros) => (metros / 80).ceil().clamp(1, 999);

/// La distancia como una barra cuya longitud son los minutos a pie (hasta 30;
/// más lejos, la barra va llena y el texto dice que conviene ir en auto).
class BarraDistancia extends StatelessWidget {
  final double metros;
  final Color esmalte;

  const BarraDistancia({super.key, required this.metros, required this.esmalte});

  @override
  Widget build(BuildContext context) {
    final minutos = minutosCaminando(metros);
    final lejos = minutos > 30;
    return Row(
      children: [
        Text(textoDistancia(metros), style: AppTypography.cifra(size: 17)),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(color: AppColors.surfaceAlt),
                  FractionallySizedBox(widthFactor: (minutos / 30).clamp(0.04, 1.0), child: Container(color: esmalte)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          lejos ? 'en auto' : '$minutos min a pie',
          style: AppTypography.caption.copyWith(color: AppColors.slate400),
        ),
      ],
    );
  }
}

/// Marca de los lugares de ejemplo: su foto es ilustrativa y no tienen
/// reseñas reales.
class EtiquetaEjemplo extends StatelessWidget {
  const EtiquetaEjemplo({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Lugar de ejemplo: la foto es ilustrativa',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppColors.amarillo, borderRadius: BorderRadius.circular(4)),
        child: Text('EJEMPLO', style: AppTypography.matricula(size: 13, color: AppColors.riel)),
      ),
    );
  }
}

/// Esqueleto de un casco mientras cargan los lugares.
class CascoEsqueleto extends StatefulWidget {
  const CascoEsqueleto({super.key});

  @override
  State<CascoEsqueleto> createState() => _CascoEsqueletoState();
}

class _CascoEsqueletoState extends State<CascoEsqueleto> with SingleTickerProviderStateMixin {
  late final AnimationController _pulso =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducido = MediaQuery.of(context).disableAnimations;
    Widget bloque(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(4)),
        );
    final contenido = Container(
      decoration: BoxDecoration(
        color: AppColors.cubierta,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: Container(color: AppColors.surfaceAlt)),
          Container(height: kFranja, color: AppColors.borderSubtle),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bloque(180, 16), const SizedBox(height: 10), bloque(110, 12)],
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: 'Cargando lugares',
      child: reducido ? contenido : FadeTransition(opacity: Tween(begin: 0.55, end: 1.0).animate(_pulso), child: contenido),
    );
  }
}
