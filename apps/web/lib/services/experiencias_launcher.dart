import 'dart:math' as math;

import '../models/lugar.dart';

/// Lanzado cuando todavía no hay un visor configurado para esa experiencia.
class ExperienciaNoConfigurada implements Exception {
  final ExperienciaTipo tipo;
  const ExperienciaNoConfigurada(this.tipo);
}

/// Punto de conexión con quien ejecuta realmente cada experiencia: el
/// módulo Unity (RA de marcador y de ubicación) y el visor 3D/360°.
///
/// La interfaz nunca abre la cámara ni carga modelos por su cuenta: llama a
/// [ExperienciasLauncher.current]. Por defecto no hay nada configurado y la
/// interfaz muestra "Próximamente". La app móvil (o el visor web, cuando
/// exista) lo reemplaza en su `main()` antes de `runApp`:
///
/// ```dart
/// ExperienciasLauncher.current = UnityExperienciasLauncher();
/// ```
abstract class ExperienciasLauncher {
  static ExperienciasLauncher current = const _SinConfigurar();

  /// Si este dispositivo puede ejecutar el tipo (p. ej. la web no tiene RA).
  bool soporta(ExperienciaTipo tipo);

  Future<void> abrir(Lugar lugar, ExperienciaTipo tipo);
}

class _SinConfigurar implements ExperienciasLauncher {
  const _SinConfigurar();

  @override
  bool soporta(ExperienciaTipo tipo) => false;

  @override
  Future<void> abrir(Lugar lugar, ExperienciaTipo tipo) async => throw ExperienciaNoConfigurada(tipo);
}

/// Posición del visitante para desbloquear la RA por ubicación. Igual que
/// [ExperienciasLauncher], cada plataforma pone la suya; sin configurar
/// devuelve `null` y la interfaz pide activar la ubicación.
abstract class UbicacionProvider {
  static UbicacionProvider current = const _SinUbicacion();

  Future<Coordenadas?> actual();
}

class _SinUbicacion implements UbicacionProvider {
  const _SinUbicacion();

  @override
  Future<Coordenadas?> actual() async => null;
}

/// Distancia en metros entre dos puntos (fórmula de haversine).
double distanciaMetros(Coordenadas a, Coordenadas b) {
  const radioTierra = 6371000.0;
  double rad(double g) => g * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * radioTierra * math.asin(math.sqrt(h));
}

String formatoDistancia(double metros) =>
    metros < 1000 ? '${metros.round()} m' : '${(metros / 1000).toStringAsFixed(1)} km';
