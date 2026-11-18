import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/services/auth_service.dart' show apiUrl;
import 'package:touristmar_web/services/experiencias_launcher.dart';
import 'package:touristmar_web/services/visor_flutter_launcher.dart';

import 'aruco_page.dart';

/// Abre las experiencias en la app móvil:
///
/// - RA con marcador, dos motores:
///   - Códigos **ArUco** 4x4 (los de chev.me/arucogen): OpenCV en Flutter
///     ([ArucoPage]). ARCore no reconoce los ArUco (tienen muy pocos "puntos
///     de detalle"), por eso no los puede leer Unity.
///   - Marcadores de **foto/imagen**: el módulo de Unity con ARCore (pantalla
///     nativa aparte, ver android/app/src/main/kotlin/.../MainActivity.kt),
///     solo si el build lo trae.
///   Si están los dos, se pregunta cuál usar.
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
      tipo == ExperienciaTipo.arMarcador || const VisorFlutterLauncher().soporta(tipo);

  /// La RA por geolocalización mide la distancia al lugar.
  @override
  bool mideDistancia(ExperienciaTipo tipo) => tipo == ExperienciaTipo.arGeo;

  @override
  Future<void> abrir(BuildContext context, Lugar lugar, ExperienciaTipo tipo) async {
    if (!soporta(tipo)) throw ExperienciaNoConfigurada(tipo);
    if (tipo != ExperienciaTipo.arMarcador) return const VisorFlutterLauncher().abrir(context, lugar, tipo);

    final motor = _unityIncluido ? await _elegirMotor(context) : _Motor.aruco;
    if (motor == null || !context.mounted) return; // cerró la hoja sin elegir
    switch (motor) {
      case _Motor.aruco:
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ArucoPage(lugar: lugar)));
      case _Motor.imagen:
        await _abrirUnity('marcadores', lugarId: lugar.id);
    }
  }

  Future<_Motor?> _elegirMotor(BuildContext context) => showModalBottomSheet<_Motor>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('¿Qué tipo de marcador vas a escanear?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_2),
                  title: const Text('Código ArUco'),
                  subtitle: const Text('Cuadro blanco y negro (como un QR pequeño)'),
                  onTap: () => Navigator.pop(context, _Motor.aruco),
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Imagen o foto'),
                  subtitle: const Text('Póster, fotografía o logotipo'),
                  onTap: () => Navigator.pop(context, _Motor.imagen),
                ),
              ],
            ),
          ),
        ),
      );

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

enum _Motor { aruco, imagen }
