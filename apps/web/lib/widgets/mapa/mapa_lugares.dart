import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../models/lugar.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_controller.dart';

/// Plantilla de mosaicos del mapa. Por defecto, los servidores de
/// OpenStreetMap: sin API key, pero pensados para poco tráfico y exigen que
/// el navegador mande Referer (ver `referrerPolicy` en el backend). Para
/// producción con más visitas se cambia sin tocar código, p. ej. MapTiler:
///   --dart-define=MAP_TILE_URL=https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=TU_KEY
const mapTileUrl = String.fromEnvironment(
  'MAP_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

LatLng toLatLng(Coordenadas c) => LatLng(c.lat, c.lng);

Coordenadas toCoordenadas(LatLng p) => Coordenadas(p.latitude, p.longitude);

/// Mapa base de la app (OpenStreetMap vía CARTO, claro u oscuro según el
/// tema). Todas las pantallas con mapa lo usan para que se vean iguales;
/// cada una le pasa sus propias capas en [children] (pines, radios, etc.).
class MapaBase extends StatelessWidget {
  final MapController? controller;
  final Coordenadas centro;
  final double zoom;
  final List<Widget> children;
  final void Function(Coordenadas punto)? onTap;
  final bool interactivo;

  /// false = la rueda del mouse no hace zoom (para mapas dentro de una página
  /// con scroll: si no, al bajar por la página el mapa se "traga" la rueda).
  final bool zoomConRueda;

  const MapaBase({
    super.key,
    this.controller,
    this.centro = centroManzanillo,
    this.zoom = 12.5,
    this.children = const [],
    this.onTap,
    this.interactivo = true,
    this.zoomConRueda = true,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: toLatLng(centro),
        initialZoom: zoom,
        minZoom: 9,
        maxZoom: 18,
        backgroundColor: AppColors.panelNavySoft,
        onTap: onTap == null ? null : (_, punto) => onTap!(toCoordenadas(punto)),
        interactionOptions: InteractionOptions(
          flags: !interactivo
              ? InteractiveFlag.none
              : InteractiveFlag.all & ~InteractiveFlag.rotate & (zoomConRueda ? InteractiveFlag.all : ~InteractiveFlag.scrollWheelZoom),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: mapTileUrl,
          userAgentPackageName: 'mx.touristmar.web',
          tileBuilder: ThemeController.isDark ? darkModeTileBuilder : null,
        ),
        ...children,
        const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
      ],
    );
  }
}

/// Pin de un lugar: círculo con el ícono de su categoría y, si el lugar
/// tiene experiencias, un puntito "RA" en la esquina.
class PinLugar extends StatelessWidget {
  final Lugar lugar;
  final bool seleccionado;

  const PinLugar({super.key, required this.lugar, this.seleccionado = false});

  static const ancho = 46.0;
  static const alto = 56.0;

  @override
  Widget build(BuildContext context) {
    final color = lugar.categoria.color;
    final size = seleccionado ? 42.0 : 34.0;
    return SizedBox(
      width: ancho,
      height: alto,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            child: CustomPaint(size: const Size(12, 8), painter: _PuntaPin(color)),
          ),
          Positioned(
            bottom: 7,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: seleccionado ? 3 : 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Icon(lugar.categoria.icon, size: size * 0.5, color: Colors.white),
            ),
          ),
          if (lugar.tieneExperiencias)
            Positioned(
              top: seleccionado ? 0 : 6,
              right: seleccionado ? 0 : 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.scrimDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: const Text('RA', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PuntaPin extends CustomPainter {
  final Color color;
  _PuntaPin(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PuntaPin old) => old.color != color;
}

/// Capa de pines para una lista de lugares (los que no tienen ubicación se
/// omiten).
MarkerLayer capaLugares(
  List<Lugar> lugares, {
  String? seleccionadoId,
  ValueChanged<Lugar>? onTap,
}) {
  final conUbicacion = lugares.where((l) => l.ubicacion != null).toList()
    // El seleccionado va al final para dibujarse encima de los demás.
    ..sort((a, b) => (a.id == seleccionadoId ? 1 : 0) - (b.id == seleccionadoId ? 1 : 0));
  return MarkerLayer(
    markers: [
      for (final l in conUbicacion)
        Marker(
          point: toLatLng(l.ubicacion!),
          width: PinLugar.ancho,
          height: PinLugar.alto,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: onTap == null ? null : () => onTap(l),
            child: MouseRegion(
              cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
              child: PinLugar(lugar: l, seleccionado: l.id == seleccionadoId),
            ),
          ),
        ),
    ],
  );
}

/// Círculo del radio de desbloqueo de la RA por ubicación.
CircleLayer capaRadio(Coordenadas centro, double metros, Color color) {
  return CircleLayer(
    circles: [
      CircleMarker(
        point: toLatLng(centro),
        radius: metros,
        useRadiusInMeter: true,
        color: color.withValues(alpha: 0.15),
        borderColor: color.withValues(alpha: 0.7),
        borderStrokeWidth: 2,
      ),
    ],
  );
}

/// Botones flotantes de zoom / recentrar, con el mismo estilo que el resto
/// de la app.
class ControlesMapa extends StatelessWidget {
  final MapController controller;
  final Coordenadas centro;
  final double zoomInicial;

  const ControlesMapa({super.key, required this.controller, this.centro = centroManzanillo, this.zoomInicial = 12.5});

  @override
  Widget build(BuildContext context) {
    Widget boton(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 18, color: AppColors.textPrimary)),
            ),
          ),
        );

    final divisor = Container(height: 1, width: 40, color: AppColors.borderSubtle);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelNavySoft,
        borderRadius: BorderRadius.circular(AppRadius.buttonLg),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          boton(Icons.add, 'Acercar', () => controller.move(controller.camera.center, controller.camera.zoom + 1)),
          divisor,
          boton(Icons.remove, 'Alejar', () => controller.move(controller.camera.center, controller.camera.zoom - 1)),
          divisor,
          boton(Icons.my_location, 'Centrar en Manzanillo', () => controller.move(toLatLng(centro), zoomInicial)),
        ],
      ),
    );
  }
}
