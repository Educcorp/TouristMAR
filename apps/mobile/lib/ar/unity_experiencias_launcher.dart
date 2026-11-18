import 'package:flutter/material.dart';
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/services/experiencias_launcher.dart';
import 'package:touristmar_web/services/visor_flutter_launcher.dart';

import 'aruco_page.dart';

/// Abre las experiencias en la app móvil. Todo se hace en Flutter:
///
/// - RA con marcador: marcadores **ArUco** 4x4 detectados con OpenCV
///   ([ArucoPage]). Antes la hacía Unity con ARCore, pero ARCore no reconoce
///   los ArUco (muy pocos "puntos de detalle"), así que ya no se usa Unity.
/// - RA por geolocalización y recorrido 360°: [VisorFlutterLauncher], igual
///   que la web.
///
/// (El nombre de la clase se conserva para no tocar main.dart.)
class UnityExperienciasLauncher implements ExperienciasLauncher {
  const UnityExperienciasLauncher._();

  static Future<UnityExperienciasLauncher> crear() async => const UnityExperienciasLauncher._();

  @override
  bool soporta(ExperienciaTipo tipo) =>
      tipo == ExperienciaTipo.arMarcador || const VisorFlutterLauncher().soporta(tipo);

  /// La RA por geolocalización mide la distancia al lugar.
  @override
  bool mideDistancia(ExperienciaTipo tipo) => tipo == ExperienciaTipo.arGeo;

  @override
  Future<void> abrir(BuildContext context, Lugar lugar, ExperienciaTipo tipo) async {
    if (!soporta(tipo)) throw ExperienciaNoConfigurada(tipo);
    if (tipo == ExperienciaTipo.arMarcador) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ArucoPage(lugar: lugar)));
      return;
    }
    return const VisorFlutterLauncher().abrir(context, lugar, tipo);
  }
}
