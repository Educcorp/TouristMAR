import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/services/auth_service.dart' show apiUrl;
import 'package:touristmar_web/services/experiencias_launcher.dart';
import 'package:touristmar_web/services/visor_flutter_launcher.dart';

/// Abre las experiencias en la app móvil:
///
/// - RA con marcador: el módulo de Unity con ARCore (pantalla nativa aparte,
///   ver android/app/src/main/kotlin/.../MainActivity.kt), que reconoce las
///   imágenes de "Marcadores de RA" y muestra la historia del lugar. Solo si
///   el build trae Unity.
/// - RA por geolocalización y recorrido 360°: siempre Flutter
///   ([VisorFlutterLauncher]), igual que la web.
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
      incluido = false; // iOS / escritorio: sin módulo de Unity
    }
    return UnityExperienciasLauncher._(incluido);
  }

  @override
  bool soporta(ExperienciaTipo tipo) =>
      (tipo == ExperienciaTipo.arMarcador && _unityIncluido) || const VisorFlutterLauncher().soporta(tipo);

  /// La RA por geolocalización mide la distancia al lugar.
  @override
  bool mideDistancia(ExperienciaTipo tipo) => tipo == ExperienciaTipo.arGeo;

  @override
  Future<void> abrir(BuildContext context, Lugar lugar, ExperienciaTipo tipo) async {
    if (!soporta(tipo)) throw ExperienciaNoConfigurada(tipo);
    if (tipo != ExperienciaTipo.arMarcador) return const VisorFlutterLauncher().abrir(context, lugar, tipo);

    await _abrirUnity('marcadores', lugarId: lugar.id);
  }

  Future<void> _abrirUnity(String escena, {String parametro = '', required String lugarId}) async {
    try {
      // apiBaseUrl: la misma API que usa la app, así Unity nunca apunta a otro
      // backend. lugarId: el mismo id que usa Flutter.
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

