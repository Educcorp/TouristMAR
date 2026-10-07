import 'dart:math' as math;

import 'package:flutter/widgets.dart' show BuildContext;

import '../models/lugar.dart';

/// Lanzado cuando todavía no hay un visor configurado para esa experiencia.
class ExperienciaNoConfigurada implements Exception {
  final ExperienciaTipo tipo;
  const ExperienciaNoConfigurada(this.tipo);
}

/// El visor existe pero no pudo abrirse (p. ej. se negó el permiso de la
/// cámara). [mensaje] se le muestra tal cual al visitante.
class ExperienciaError implements Exception {
  final String mensaje;
  const ExperienciaError(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Punto de conexión con quien ejecuta realmente cada experiencia: el
/// módulo Unity (RA de marcador, RA de ubicación y recorrido 360°).
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

  /// Si el visor mide por su cuenta qué tan cerca está el visitante (la RA por
  /// ubicación de Unity muestra un resumen de lejos y el detalle al llegar).
  /// Entonces la interfaz no bloquea el botón esperando la ubicación.
  bool mideDistancia(ExperienciaTipo tipo) => false;

  /// [context] sirve para preguntarle algo al visitante antes de abrir (p. ej.
  /// qué recorrido ver si el lugar no tiene uno asignado).
  Future<void> abrir(BuildContext context, Lugar lugar, ExperienciaTipo tipo);
}

class _SinConfigurar implements ExperienciasLauncher {
  const _SinConfigurar();

  @override
  bool soporta(ExperienciaTipo tipo) => false;

  @override
  bool mideDistancia(ExperienciaTipo tipo) => false;

  @override
  Future<void> abrir(BuildContext context, Lugar lugar, ExperienciaTipo tipo) async => throw ExperienciaNoConfigurada(tipo);
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

/// Rumbo de [desde] hacia [hasta] en grados (0 = norte, 90 = este), el
/// mismo eje que la brújula.
double rumboHacia(Coordenadas desde, Coordenadas hasta) {
  double rad(double g) => g * math.pi / 180;
  final f1 = rad(desde.lat);
  final f2 = rad(hasta.lat);
  final dl = rad(hasta.lng - desde.lng);
  final y = math.sin(dl) * math.cos(f2);
  final x = math.cos(f1) * math.sin(f2) - math.sin(f1) * math.cos(f2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Diferencia entre dos rumbos llevada a -180…180 (positivo = a la derecha).
double diferenciaAngulo(double a, double b) => ((a - b + 540) % 360) - 180;

String formatoDistancia(double metros) =>
    metros < 1000 ? '${metros.round()} m' : '${(metros / 1000).toStringAsFixed(1)} km';
