import 'package:geolocator/geolocator.dart';

import '../models/lugar.dart';
import 'experiencias_launcher.dart';

/// Ubicación real del visitante con `geolocator`: en la web la del navegador
/// (pide permiso la primera vez) y en el teléfono el GPS. Se registra en
/// `main.dart` como [UbicacionProvider.current].
class UbicacionDispositivo implements UbicacionProvider {
  const UbicacionDispositivo();

  /// null = sin permiso, ubicación apagada o el navegador no la da.
  @override
  Future<Coordenadas?> actual() async {
    if (!await _permiso()) return null;
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      return Coordenadas(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Posición en vivo mientras el visitante camina (cada ~5 m). Vacío si no
  /// hay permiso.
  static Stream<Coordenadas> seguir() async* {
    if (!await _permiso()) return;
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).map((p) => Coordenadas(p.latitude, p.longitude));
  }

  static Future<bool> _permiso() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      return permiso == LocationPermission.always || permiso == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }
}
