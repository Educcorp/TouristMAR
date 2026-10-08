import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/services/auth_service.dart' show apiUrl;
import 'package:touristmar_web/services/experiencias_launcher.dart';
import 'package:touristmar_web/services/ra_ubicacion.dart' show sinRaUbicacion;
import 'package:touristmar_web/services/visor_flutter_launcher.dart';

/// Abre las experiencias del módulo de Unity (una pantalla nativa aparte, ver
/// android/app/src/main/kotlin/.../MainActivity.kt). La escena "Arranque" de
/// Unity abre la que se le pida y recibe siempre el **id del lugar** (extra
/// `lugarId`):
///
/// - RA con marcador (escena "marcadores"): Unity baja los marcadores del
///   lugar con GET /api/marcadores?negocioId={lugarId} (sin lugarId, todos).
/// - RA por geolocalización (escena "geo", `parametro` = id del lugar): Unity
///   baja los puntos del lugar con GET /api/ra/lugares/{lugarId}.
/// - Recorrido 360°: siempre lo hace Flutter ([VisorFlutterLauncher]), no
///   Unity.
///
/// Sin Unity en el build, la RA por geolocalización también la hace Flutter
/// (lo mismo que la web).
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

  /// El recorrido 360° y la RA por geolocalización se abren con Flutter
  /// aunque el build no traiga Unity; la RA con marcador sí necesita Unity.
  @override
  bool soporta(ExperienciaTipo tipo) => _unityIncluido || const VisorFlutterLauncher().soporta(tipo);

  /// Las dos versiones de la RA por geolocalización miden la distancia.
  @override
  bool mideDistancia(ExperienciaTipo tipo) => tipo == ExperienciaTipo.arGeo;

  @override
  Future<void> abrir(BuildContext context, Lugar lugar, ExperienciaTipo tipo) async {
    if (!soporta(tipo)) throw ExperienciaNoConfigurada(tipo);
    final enUnity = _unityIncluido && tipo != ExperienciaTipo.recorrido360;
    if (!enUnity) return const VisorFlutterLauncher().abrir(context, lugar, tipo);
    switch (tipo) {
      case ExperienciaTipo.arMarcador:
        await _abrirUnity('marcadores', lugarId: lugar.id);
      case ExperienciaTipo.arGeo:
        if (lugar.ubicacion == null) throw ExperienciaError(sinRaUbicacion(lugar.nombre));
        await _abrirUnity('geo', parametro: lugar.id, lugarId: lugar.id);
      case ExperienciaTipo.recorrido360:
        break; // nunca llega: lo abre Flutter arriba
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
}
