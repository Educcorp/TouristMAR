import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/services/auth_service.dart' show apiUrl;
import 'package:touristmar_web/services/experiencias_launcher.dart';
import 'package:touristmar_web/services/ra_ubicacion.dart' show sinRaUbicacion;
import 'package:touristmar_web/services/recorridos_service.dart';
import 'package:touristmar_web/services/visor_flutter_launcher.dart';

/// true = la RA por geolocalización la abre Unity (escena "geo") en vez de
/// Flutter. Por defecto la hace Flutter (ver docs/manuals/ra_geolocalizacion.md):
///   flutter run --dart-define=RA_GEO_EN_UNITY=true
const _raGeoEnUnity = bool.fromEnvironment('RA_GEO_EN_UNITY');

/// Abre las experiencias del módulo de Unity (una pantalla nativa aparte, ver
/// android/app/src/main/kotlin/.../MainActivity.kt). La escena "Arranque" de
/// Unity abre la que se le pida y recibe siempre el **id del lugar** (extra
/// `lugarId`), el mismo con el que Flutter pide GET /api/ra/lugares/{id}:
///
/// - RA con marcador (escena "marcadores"): Unity baja los marcadores del
///   lugar con GET /api/marcadores?negocioId={lugarId} (sin lugarId, todos).
///   Se abre desde la ficha o desde el radio cercano de la RA geo de Flutter.
/// - Recorrido 360° (escena "recorrido"): `parametro` = nombre del recorrido
///   del lugar (GET /api/recorridos/{nombre}); si no tiene, solo se avisa.
/// - RA por geolocalización: la hace Flutter ([VisorFlutterLauncher]) sobre
///   los puntos del lugar, salvo con [_raGeoEnUnity] (escena "geo",
///   `parametro` = id del lugar).
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

  /// Sin Unity en el build, el recorrido 360° y la RA por geolocalización se
  /// abren igual con Flutter (lo mismo que la web); la RA con marcador sí
  /// necesita Unity.
  @override
  bool soporta(ExperienciaTipo tipo) => _unityIncluido || const VisorFlutterLauncher().soporta(tipo);

  /// Las dos versiones de la RA por geolocalización miden la distancia.
  @override
  bool mideDistancia(ExperienciaTipo tipo) => tipo == ExperienciaTipo.arGeo;

  @override
  Future<void> abrir(BuildContext context, Lugar lugar, ExperienciaTipo tipo) async {
    if (!soporta(tipo)) throw ExperienciaNoConfigurada(tipo);
    final enUnity = _unityIncluido && (tipo != ExperienciaTipo.arGeo || _raGeoEnUnity);
    if (!enUnity) return const VisorFlutterLauncher().abrir(context, lugar, tipo);
    switch (tipo) {
      case ExperienciaTipo.arMarcador:
        await _abrirUnity('marcadores', lugarId: lugar.id);
      case ExperienciaTipo.recorrido360:
        await _abrirUnity('recorrido', parametro: await _recorridoDe(lugar), lugarId: lugar.id);
      case ExperienciaTipo.arGeo:
        if (lugar.ubicacion == null) throw ExperienciaError(sinRaUbicacion(lugar.nombre));
        await _abrirUnity('geo', parametro: lugar.id, lugarId: lugar.id);
    }
  }

  Future<void> _abrirUnity(String escena, {String parametro = '', required String lugarId}) async {
    try {
      // apiBaseUrl: la misma API que usa la app, así Unity nunca apunta a otro
      // backend. lugarId: el mismo id que usa Flutter (GET /api/ra/lugares/{id}).
      await _canal.invokeMethod<void>('abrir', {
        'escena': escena,
        'parametro': parametro,
        'apiBaseUrl': apiUrl,
        'lugarId': lugarId,
      });
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
}
