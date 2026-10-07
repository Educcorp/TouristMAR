import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart' show apiUrl, AuthError, crearClienteHttp;

/// Marcador AR tal como lo ve el panel de administración
/// (`GET /api/admin/ar/marcadores`).
class ArMarcador {
  final String id;
  final String nombre;
  final String imagenUrl;
  final double? anchoMetros;
  final String titulo;
  final String texto;
  final String tipoContenido;
  final String? contenidoUrl;
  final String? negocioId;
  final String? negocioNombre;
  final bool activo;
  final int escaneos;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ArMarcador({
    required this.id,
    required this.nombre,
    required this.imagenUrl,
    this.anchoMetros,
    required this.titulo,
    required this.texto,
    required this.tipoContenido,
    this.contenidoUrl,
    this.negocioId,
    this.negocioNombre,
    required this.activo,
    required this.escaneos,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ArMarcador.fromJson(Map<String, dynamic> json) => ArMarcador(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        imagenUrl: json['imagenUrl'] as String,
        anchoMetros: (json['anchoMetros'] as num?)?.toDouble(),
        titulo: json['titulo'] as String,
        texto: json['texto'] as String,
        tipoContenido: json['tipoContenido'] as String? ?? 'texto',
        contenidoUrl: json['contenidoUrl'] as String?,
        negocioId: json['negocioId'] as String?,
        negocioNombre: json['negocioNombre'] as String?,
        activo: json['activo'] as bool? ?? true,
        escaneos: (json['escaneos'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

/// CRUD de marcadores AR para admin / super_admin. La app móvil no usa esto:
/// Unity lee directo el endpoint público `GET /api/ar/marcadores`.
class ArService {
  final http.Client _client;

  ArService({http.Client? client}) : _client = client ?? crearClienteHttp();

  Future<List<ArMarcador>> listMarcadores(String token) async {
    final res = await _client.get(
      Uri.parse('$apiUrl/admin/ar/marcadores'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _check(res, 'No se pudieron cargar los marcadores');
    return (data['marcadores'] as List).map((m) => ArMarcador.fromJson(m as Map<String, dynamic>)).toList();
  }

  /// Solo PNG o JPG (lo que Unity puede decodificar en el celular).
  Future<ArMarcador> createMarcador(
    String token, {
    required Uint8List imagen,
    required String filename,
    required String nombre,
    required String titulo,
    required String texto,
    double? anchoMetros,
    String? negocioId,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/admin/ar/marcadores'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields.addAll({
        'nombre': nombre,
        'titulo': titulo,
        'texto': texto,
        'anchoMetros': anchoMetros?.toString() ?? '',
        'negocioId': negocioId ?? '',
      })
      ..files.add(_imagenPart(imagen, filename));

    final res = await http.Response.fromStream(await _client.send(request));
    final data = _check(res, 'No se pudo crear el marcador');
    return ArMarcador.fromJson(data['marcador'] as Map<String, dynamic>);
  }

  /// `fields` acepta: nombre, titulo, texto, anchoMetros, negocioId, activo,
  /// tipoContenido, contenidoUrl.
  Future<ArMarcador> updateMarcador(String token, String id, Map<String, dynamic> fields) async {
    final res = await _client.patch(
      Uri.parse('$apiUrl/admin/ar/marcadores/$id'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(fields),
    );
    final data = _check(res, 'No se pudo actualizar el marcador');
    return ArMarcador.fromJson(data['marcador'] as Map<String, dynamic>);
  }

  Future<ArMarcador> replaceImagen(String token, String id, Uint8List imagen, String filename) async {
    final request = http.MultipartRequest('PUT', Uri.parse('$apiUrl/admin/ar/marcadores/$id/imagen'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(_imagenPart(imagen, filename));

    final res = await http.Response.fromStream(await _client.send(request));
    final data = _check(res, 'No se pudo reemplazar la imagen');
    return ArMarcador.fromJson(data['marcador'] as Map<String, dynamic>);
  }

  Future<void> deleteMarcador(String token, String id) async {
    final res = await _client.delete(
      Uri.parse('$apiUrl/admin/ar/marcadores/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _check(res, 'No se pudo eliminar el marcador');
  }

  http.MultipartFile _imagenPart(Uint8List bytes, String filename) {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
    return http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType('image', ext == 'png' ? 'png' : 'jpeg'),
    );
  }

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
