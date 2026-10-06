import 'package:flutter/widgets.dart';

import '../models/lugar.dart';
import '../navegacion/rutas.dart';
import 'experiencias_launcher.dart';
import 'recorridos_service.dart';

/// Abre el recorrido 360° con el visor de Flutter ([Recorrido360Page]). Lo
/// usa la web (no tiene Unity) y la app móvil cuando el build no trae el
/// módulo de Unity. La RA (marcador y ubicación) necesita la cámara del
/// teléfono y sigue siendo solo de Unity.
class VisorFlutterLauncher implements ExperienciasLauncher {
  final RecorridosService? _service;

  const VisorFlutterLauncher([this._service]);

  @override
  bool soporta(ExperienciaTipo tipo) => tipo == ExperienciaTipo.recorrido360;

  @override
  bool mideDistancia(ExperienciaTipo tipo) => false;

  @override
  Future<void> abrir(BuildContext context, Lugar lugar, ExperienciaTipo tipo) async {
    if (!soporta(tipo)) throw ExperienciaNoConfigurada(tipo);
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
