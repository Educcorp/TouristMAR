import 'dart:convert';

import 'package:http/http.dart' as http;

/// Geocodificación inversa (coordenadas -> dirección aproximada) vía Nominatim,
/// el mismo proveedor de OpenStreetMap que ya usa el mapa (flutter_map). No
/// necesita llave: basta con no abusar del servicio (se llama una vez por
/// cada pin que se coloca, no en bucle).
class GeocodingService {
  static Future<String?> direccionAproximada(double lat, double lng) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': '$lat',
      'lon': '$lng',
      'zoom': '18',
      'accept-language': 'es',
    });
    try {
      final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final texto = data['display_name'] as String?;
      return (texto == null || texto.trim().isEmpty) ? null : texto.trim();
    } catch (_) {
      // Sin conexión o el servicio no respondió a tiempo: se deja que la
      // dirección se siga escribiendo a mano.
      return null;
    }
  }
}
