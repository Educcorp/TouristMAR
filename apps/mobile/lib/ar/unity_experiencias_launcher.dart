import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/services/auth_service.dart' show apiUrl;
import 'package:touristmar_web/services/experiencias_launcher.dart';
import 'package:touristmar_web/services/ra_ubicacion.dart';
import 'package:touristmar_web/services/recorridos_service.dart';
import 'package:touristmar_web/services/visor_flutter_launcher.dart';

/// Abre las experiencias del módulo de Unity (una pantalla nativa aparte, ver
/// android/app/src/main/kotlin/.../MainActivity.kt). El módulo trae las tres
/// como escenas y la escena "Arranque" abre la que se le pida:
///
/// - RA con marcador: Unity baja todos los marcadores de GET /api/marcadores y
///   reconoce cualquiera, así que no necesita saber de qué lugar se abrió.
/// - Recorrido 360°: se le pasa el nombre del recorrido del lugar
///   (GET /api/recorridos); si el lugar no tiene uno, solo se avisa.
/// - RA por ubicación: se le pasa el nombre de la playa del lugar (lista fija
///   en Unity, ControladorPlayas.cs; el propio visor mide la distancia); si el
///   lugar no es una de esas playas, solo se avisa.
class UnityExperienciasLauncher implements ExperienciasLauncher {
  static const _canal = MethodChannel('touristmar/ar');

  final bool _unityIncluido;

  UnityExperienciasLauncher._(this._unityIncluido);

  /// Pregunta a Android si este build trae el módulo de Unity.
  static Future<UnityExperienciasLauncher> crear() async {
    bool incluido;
    try {
      incluido = await _canal.invokeMethod<bool>('disponible') ?? false;
    } on MissingPluginException {
      incluido = false; // iOS / escritorio: todavía sin módulo de Unity
    }
    return UnityExperienciasLauncher._(incluido);
  }

  /// Sin Unity en el build, el recorrido 360° se abre igual con el visor de
  /// Flutter (el mismo de la web); la RA sí necesita Unity.
  @override
  bool soporta(ExperienciaTipo tipo) => _unityIncluido || tipo == ExperienciaTipo.recorrido360;

  @override
  bool mideDistancia(ExperienciaTipo tipo) => _unityIncluido && tipo == ExperienciaTipo.arGeo;

  @override
  Future<void> abrir(BuildContext context, Lugar lugar, ExperienciaTipo tipo) async {
    if (!soporta(tipo)) throw ExperienciaNoConfigurada(tipo);
    if (!_unityIncluido) return const VisorFlutterLauncher().abrir(context, lugar, tipo);
    switch (tipo) {
      case ExperienciaTipo.arMarcador:
        await _abrirUnity('marcadores');
      case ExperienciaTipo.recorrido360:
        await _abrirUnity('recorrido', await _recorridoDe(lugar));
      case ExperienciaTipo.arGeo:
        await _abrirUnity('geo', _playaDe(lugar));
    }
  }

  Future<void> _abrirUnity(String escena, [String parametro = '']) async {
    try {
      // apiBaseUrl: la misma API que usa la app (el visor 360° pide
      // GET {apiBaseUrl}/recorridos/{parametro}), así nunca apunta a otro backend.
      await _canal.invokeMethod<void>('abrir', {'escena': escena, 'parametro': parametro, 'apiBaseUrl': apiUrl});
    } on PlatformException catch (e) {
      throw ExperienciaError(e.message ?? 'No se pudo abrir la experiencia.');
    }
  }

  /// Solo el recorrido propio del lugar (ver [recorridoDeLugar]). Si el lugar
  /// todavía no tiene uno se avisa: nunca se ofrecen recorridos de otros lugares.
  Future<String> _recorridoDe(Lugar lugar) async {
    final List<RecorridoPublico> recorridos;
    try {
      recorridos = await RecorridosService().listPublicos();
    } catch (_) {
      throw const ExperienciaError('No se pudieron cargar los recorridos 360°. Revisa tu conexión.');
    }
    final propio = recorridoDeLugar(recorridos, lugarId: lugar.id, lugarNombre: lugar.nombre);
    if (propio == null) throw ExperienciaError(sinRecorrido360(lugar.nombre));
    return propio.nombre;
  }

  /// Solo la playa del lugar (ver [playaParaLugar]). Si el lugar no tiene RA
  /// por ubicación se avisa: nunca se ofrecen otras playas.
  String _playaDe(Lugar lugar) {
    final playa = playaParaLugar(lugar.nombre);
    if (playa == null) throw ExperienciaError(sinRaUbicacion(lugar.nombre));
    return playa;
  }
}
