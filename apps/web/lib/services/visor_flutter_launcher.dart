import 'package:flutter/widgets.dart';

import '../models/lugar.dart';
import '../navegacion/rutas.dart';
import '../pages/ra_ubicacion_page.dart';
import 'experiencias_launcher.dart';
import 'ra_ubicacion.dart' show sinRaUbicacion;
import 'recorridos_service.dart';

/// Experiencias hechas en Flutter, sin Unity: el recorrido 360° con el
/// visor de Flutter ([Recorrido360Page]) y la RA por ubicación con cámara,
/// GPS y brújula ([RaUbicacionPage]) sobre los puntos del lugar. Lo usa la
/// web, y la app móvil para el 360° (siempre) y para la RA por
/// geolocalización cuando su build no trae Unity. La RA con marcador
/// sigue siendo solo de Unity.
class VisorFlutterLauncher implements ExperienciasLauncher {
  final RecorridosService? _service;

  const VisorFlutterLauncher([this._service]);

  @override
  bool soporta(ExperienciaTipo tipo) => tipo == ExperienciaTipo.recorrido360 || tipo == ExperienciaTipo.arGeo;

  @override
  /// La RA por ubicación se puede abrir desde lejos: ella misma muestra la
  /// distancia y hacia dónde está el lugar.
  bool mideDistancia(ExperienciaTipo tipo) => tipo == ExperienciaTipo.arGeo;

  @override
  Future<void> abrir(BuildContext context, Lugar lugar, ExperienciaTipo tipo) async {
    if (!soporta(tipo)) throw ExperienciaNoConfigurada(tipo);
    if (tipo == ExperienciaTipo.arGeo) {
      if (lugar.ubicacion == null) throw ExperienciaError(sinRaUbicacion(lugar.nombre));
      await abrirRaUbicacion(context, lugar);
      return;
    }
    final List<RecorridoPublico> recorridos;
    try {
      recorridos = await (_service ?? RecorridosService()).listPublicos();
    } catch (_) {
      throw const ExperienciaError('No se pudieron cargar los recorridos 360°. Revisa tu conexión.');
    }
    final propio = recorridoDeLugar(recorridos, lugarId: lugar.id, lugarNombre: lugar.nombre);
    if (propio == null || propio.escenas.isEmpty) throw ExperienciaError(sinRecorrido360(lugar.nombre));
    if (!context.mounted) return;
    await abrirRecorrido(context, propio, lugarNombre: lugar.nombre);
  }
}
