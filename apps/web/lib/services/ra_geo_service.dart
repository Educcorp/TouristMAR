import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lugar.dart';
import 'auth_service.dart' show apiUrl, AuthError;

/// Radios por defecto de las capas (metros). Mismos valores que el backend
/// (RADIO_VISIBLE_DEFAULT / RADIO_CERCANO_DEFAULT en ra-geo.service.ts).
const radioVisibleDefault = 100.0;
const radioCercanoDefault = 10.0;

/// Punto de interés de la RA por geolocalización. Funciona por capas:
/// dentro de [radioVisible] la cámara muestra un marcador flotante con
/// [titulo] y [resumen]; dentro de [radioCercano] se abre la guía completa
/// ([detalle], imagen y audio).
class PuntoRaGeo {
  /// null = punto que todavía no se guarda (formulario del admin).
  final String? id;
  final String titulo;
  final String resumen;
  final String detalle;
  final String imagenUrl;
  final String audioUrl;
  final Coordenadas ubicacion;
  final double radioVisible;
  final double radioCercano;
  final int orden;
  final bool activo;

  const PuntoRaGeo({
    this.id,
    required this.titulo,
    this.resumen = '',
    this.detalle = '',
    this.imagenUrl = '',
    this.audioUrl = '',
    required this.ubicacion,
    this.radioVisible = radioVisibleDefault,
    this.radioCercano = radioCercanoDefault,
    this.orden = 0,
    this.activo = true,
  });

  /// Lee tanto la respuesta del admin (`imagenUrl`) como la pública
  /// (`urlImagen`, el contrato con Unity).
  factory PuntoRaGeo.fromJson(Map<String, dynamic> j) => PuntoRaGeo(
        id: j['id'] as String?,
        titulo: j['titulo'] as String? ?? '',
        resumen: j['resumen'] as String? ?? '',
        detalle: j['detalle'] as String? ?? '',
        imagenUrl: (j['imagenUrl'] ?? j['urlImagen']) as String? ?? '',
        audioUrl: (j['audioUrl'] ?? j['urlAudio']) as String? ?? '',
        ubicacion: Coordenadas((j['latitud'] as num).toDouble(), (j['longitud'] as num).toDouble()),
        radioVisible: (j['radioVisible'] as num?)?.toDouble() ?? radioVisibleDefault,
        radioCercano: (j['radioCercano'] as num?)?.toDouble() ?? radioCercanoDefault,
        orden: (j['orden'] as num?)?.toInt() ?? 0,
        activo: j['activo'] as bool? ?? true,
      );

  /// Sin puntos dados de alta, el pin del lugar hace de punto único (lo
  /// mismo que hace el backend).
  factory PuntoRaGeo.delLugar(Lugar lugar) => PuntoRaGeo(
        titulo: lugar.nombre,
        resumen: lugar.descripcion.length <= 140 ? lugar.descripcion : '${lugar.descripcion.substring(0, 139)}…',
        detalle: lugar.descripcion,
        imagenUrl: lugar.portada.startsWith('http') ? lugar.portada : '',
        ubicacion: lugar.ubicacion!,
        radioVisible: lugar.radioDesbloqueo,
      );

  Map<String, dynamic> toJson() => {
        'titulo': titulo,
        'resumen': resumen,
        'detalle': detalle,
        'imagenUrl': imagenUrl,
        'audioUrl': audioUrl,
        'latitud': ubicacion.lat,
        'longitud': ubicacion.lng,
        'radioVisible': radioVisible,
        'radioCercano': radioCercano,
        'activo': activo,
      };
}

/// Lo que necesita la pantalla de RA de un lugar: sus puntos y si tiene
/// marcadores de imagen (para pasar a la RA con marcadores al llegar).
class RaGeoLugar {
  final List<PuntoRaGeo> puntos;
  final bool tieneMarcadores;

  const RaGeoLugar({required this.puntos, this.tieneMarcadores = false});
}

/// Puntos de interés de la RA por geolocalización: lectura pública para la
/// app (`GET /api/ra/lugares/:id`) y gestión del admin (`/api/admin/ra-geo`).
class RaGeoService {
  final http.Client _client;

  RaGeoService({http.Client? client}) : _client = client ?? http.Client();

  /// Público: los puntos activos de un lugar (nunca vacío si el lugar tiene
  /// pin: el backend manda el pin como punto único) y si tiene marcadores.
  Future<RaGeoLugar> lugarPublico(String lugarId) async {
    final res = await _client.get(Uri.parse('$apiUrl/ra/lugares/${Uri.encodeComponent(lugarId)}'));
    final data = _check(res, 'No se pudieron cargar los puntos de RA');
    final lugar = data['lugar'] as Map<String, dynamic>;
    final puntos = (lugar['puntos'] as List?) ?? const [];
    return RaGeoLugar(
      puntos: puntos.map((p) => PuntoRaGeo.fromJson(p as Map<String, dynamic>)).toList(),
      tieneMarcadores: lugar['tieneMarcadores'] as bool? ?? false,
    );
  }

  Future<List<PuntoRaGeo>> listar(String token, String lugarId) async {
    final res = await _client.get(
      Uri.parse('$apiUrl/admin/ra-geo/lugares/$lugarId/puntos'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _check(res, 'No se pudieron cargar los puntos de RA');
    return (data['puntos'] as List).map((p) => PuntoRaGeo.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<PuntoRaGeo> crear(String token, String lugarId, PuntoRaGeo punto) async {
    final res = await _client.post(
      Uri.parse('$apiUrl/admin/ra-geo/lugares/$lugarId/puntos'),
      headers: _jsonHeaders(token),
      body: jsonEncode(punto.toJson()),
    );
    final data = _check(res, 'No se pudo guardar el punto');
    return PuntoRaGeo.fromJson(data['punto'] as Map<String, dynamic>);
  }

  Future<PuntoRaGeo> actualizar(String token, String id, Map<String, dynamic> campos) async {
    final res = await _client.patch(
      Uri.parse('$apiUrl/admin/ra-geo/puntos/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(campos),
    );
    final data = _check(res, 'No se pudo guardar el punto');
    return PuntoRaGeo.fromJson(data['punto'] as Map<String, dynamic>);
  }

  Future<void> borrar(String token, String id) async {
    final res = await _client.delete(
      Uri.parse('$apiUrl/admin/ra-geo/puntos/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _check(res, 'No se pudo borrar el punto');
  }

  Map<String, String> _jsonHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Map<String, dynamic> _check(http.Response res, String fallback) {
    Map<String, dynamic> data;
    try {
      data = res.body.isEmpty ? {} : jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? fallback);
    }
    return data;
  }
}
