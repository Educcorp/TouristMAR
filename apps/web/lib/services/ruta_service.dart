import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lugar.dart';
import 'auth_service.dart' show crearClienteHttp;

/// Ruta a pie calculada sobre las calles de OpenStreetMap.
class RutaCalculada {
  final List<Coordenadas> puntos;
  final double metros;
  final double segundos;

  const RutaCalculada({required this.puntos, required this.metros, required this.segundos});
}

/// Calcula la ruta a pie para dibujarla en nuestro mapa (en vez de mandar al
/// visitante a Google Maps). Usa el servidor OSRM público de FOSSGIS (el
/// mismo que usa openstreetmap.org para "Indicaciones"): gratuito y sin
/// clave, pero con uso razonable — no se pide más de una ruta por pantalla
/// y solo se recalcula si el visitante se aleja de ella.
class RutaService {
  final http.Client _client;

  RutaService({http.Client? client}) : _client = client ?? crearClienteHttp();

  static const _servidor = 'https://routing.openstreetmap.de/routed-foot/route/v1/foot';

  /// null = no se pudo calcular (sin conexión o sin calles cerca); la
  /// pantalla dibuja entonces una línea recta.
  Future<RutaCalculada?> aPie(Coordenadas desde, Coordenadas hasta) async {
    // OSRM recibe longitud,latitud (al revés que el resto de la app).
    final uri = Uri.parse('$_servidor/${desde.lng},${desde.lat};${hasta.lng},${hasta.lat}')
        .replace(queryParameters: {'overview': 'full', 'geometries': 'geojson'});
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rutas = data['routes'] as List?;
      if (data['code'] != 'Ok' || rutas == null || rutas.isEmpty) return null;
      final ruta = rutas.first as Map<String, dynamic>;
      final coords = (ruta['geometry'] as Map<String, dynamic>)['coordinates'] as List;
      return RutaCalculada(
        puntos: [
          for (final c in coords) Coordenadas(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble()),
        ],
        metros: (ruta['distance'] as num).toDouble(),
        segundos: (ruta['duration'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
