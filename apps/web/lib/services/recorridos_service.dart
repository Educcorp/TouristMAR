import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart' show apiUrl, AuthError;

/// Cada recorrido lleva exactamente 3 fotos 360° ("Foto 1", "Foto 2",
/// "Foto 3"). Mismo valor que `FOTOS_POR_RECORRIDO` en el backend.
const fotosPorRecorrido = 3;

/// Una de las 3 fotos 360° de un recorrido, ya optimizada por el backend (JPG
/// de máx. 4096×2048) más su miniatura, que es lo único que carga el panel.
class Escena360 {
  final String id;
  /// Casilla: 1 = "Foto 1", 2 = "Foto 2", 3 = "Foto 3".
  final int posicion;
  final String imagenUrl;
  final String miniaturaUrl;
  final int ancho;
  final int alto;
  final int pesoBytes;

  const Escena360({
    required this.id,
    required this.posicion,
    required this.imagenUrl,
    required this.miniaturaUrl,
    required this.ancho,
    required this.alto,
    required this.pesoBytes,
  });

  factory Escena360.fromJson(Map<String, dynamic> json) => Escena360(
        id: json['id'] as String,
        posicion: (json['posicion'] as num).toInt(),
        imagenUrl: json['imagenUrl'] as String,
        miniaturaUrl: json['miniaturaUrl'] as String,
        ancho: (json['ancho'] as num).toInt(),
        alto: (json['alto'] as num).toInt(),
        pesoBytes: (json['pesoBytes'] as num).toInt(),
      );
}

/// Recorrido 360° tal como lo ve el panel de administración
/// (`GET /api/admin/recorridos`).
class Recorrido360 {
  final String id;
  final String nombre;
  final String titulo;
  final String texto;
  final String? negocioId;
  final String? negocioNombre;
  final bool activo;
  final List<Escena360> escenas;

  const Recorrido360({
    required this.id,
    required this.nombre,
    required this.titulo,
    required this.texto,
    this.negocioId,
    this.negocioNombre,
    required this.activo,
    required this.escenas,
  });

  /// Lo que ve Unity: activo y con sus 3 fotos (el endpoint público además
  /// oculta los de negocios sin aprobar).
  bool get publicado => activo && escenas.length == fotosPorRecorrido;

  /// La foto de una casilla (1–3), o null si todavía no se sube.
  Escena360? foto(int posicion) {
    for (final e in escenas) {
      if (e.posicion == posicion) return e;
    }
    return null;
  }

  int get pesoTotalBytes => escenas.fold(0, (total, e) => total + e.pesoBytes);

  Recorrido360 copyWith({List<Escena360>? escenas}) => Recorrido360(
        id: id,
        nombre: nombre,
        titulo: titulo,
        texto: texto,
        negocioId: negocioId,
        negocioNombre: negocioNombre,
        activo: activo,
        escenas: escenas ?? this.escenas,
      );

  factory Recorrido360.fromJson(Map<String, dynamic> json) => Recorrido360(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        titulo: json['titulo'] as String,
        texto: json['texto'] as String,
        negocioId: json['negocioId'] as String?,
        negocioNombre: json['negocioNombre'] as String?,
        activo: json['activo'] as bool? ?? true,
        escenas: ((json['escenas'] as List?) ?? const [])
            .map((e) => Escena360.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Recorrido tal como lo publica `GET /api/recorridos` (el contrato con
/// Unity). Lo usa el panel de empresa para saber si su negocio ya tiene uno.
class RecorridoPublico {
  final String nombre;
  final String textoParaMostrar;
  final String negocioId;
  final String urlPortada;
  final int escenas;

  const RecorridoPublico({
    required this.nombre,
    required this.textoParaMostrar,
    required this.negocioId,
    required this.urlPortada,
    required this.escenas,
  });

  factory RecorridoPublico.fromJson(Map<String, dynamic> json) => RecorridoPublico(
        nombre: json['nombre'] as String,
        textoParaMostrar: json['textoParaMostrar'] as String,
        negocioId: json['negocioId'] as String? ?? '',
        urlPortada: json['urlPortada'] as String? ?? '',
        escenas: (json['escenas'] as List?)?.length ?? 0,
      );
}

/// Gestión de recorridos 360° para admin / super_admin. La app móvil no usa
/// esto: Unity lee directo el endpoint público `GET /api/recorridos`.
class RecorridosService {
  final http.Client _client;

  RecorridosService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Recorrido360>> listRecorridos(String token) async {
    final res = await _client.get(
      Uri.parse('$apiUrl/admin/recorridos'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _check(res, 'No se pudieron cargar los recorridos');
    return (data['recorridos'] as List).map((r) => Recorrido360.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Público (sin token): los recorridos que ve la app para un negocio.
  Future<List<RecorridoPublico>> listPublicos({String? negocioId}) async {
    final uri = Uri.parse('$apiUrl/recorridos')
        .replace(queryParameters: negocioId == null ? null : {'negocioId': negocioId});
    final res = await _client.get(uri);
    final data = _check(res, 'No se pudieron cargar los recorridos');
    return (data['recorridos'] as List).map((r) => RecorridoPublico.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Recorrido360> createRecorrido(
    String token, {
    required String nombre,
    required String titulo,
    required String texto,
    String? negocioId,
  }) async {
    final res = await _client.post(
      Uri.parse('$apiUrl/admin/recorridos'),
      headers: _jsonHeaders(token),
      body: jsonEncode({'nombre': nombre, 'titulo': titulo, 'texto': texto, 'negocioId': negocioId}),
    );
    final data = _check(res, 'No se pudo crear el recorrido');
    return Recorrido360.fromJson(data['recorrido'] as Map<String, dynamic>);
  }

  /// `fields` acepta: nombre, titulo, texto, negocioId, activo.
  Future<Recorrido360> updateRecorrido(String token, String id, Map<String, dynamic> fields) async {
    final res = await _client.patch(
      Uri.parse('$apiUrl/admin/recorridos/$id'),
      headers: _jsonHeaders(token),
      body: jsonEncode(fields),
    );
    final data = _check(res, 'No se pudo actualizar el recorrido');
    return Recorrido360.fromJson(data['recorrido'] as Map<String, dynamic>);
  }

  Future<void> deleteRecorrido(String token, String id) async {
    final res = await _client.delete(
      Uri.parse('$apiUrl/admin/recorridos/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _check(res, 'No se pudo eliminar el recorrido');
  }

  /// Sube (o reemplaza) la foto de una casilla: `posicion` 1 = "Foto 1"…
  /// La casilla decide el orden que ve Unity, no el orden de subida. Se
  /// manda como stream (sin cargar la foto entera en memoria del navegador);
  /// el backend la optimiza antes de guardarla.
  Future<Escena360> setEscena(
    String token,
    String recorridoId,
    int posicion, {
    required Stream<List<int>> bytes,
    required int length,
    required String filename,
  }) async {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
    final request = http.MultipartRequest('PUT', Uri.parse('$apiUrl/admin/recorridos/$recorridoId/escenas/$posicion'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile(
        'file',
        bytes,
        length,
        filename: filename,
        contentType: MediaType('image', ext == 'png' ? 'png' : 'jpeg'),
      ));

    final res = await http.Response.fromStream(await _client.send(request));
    final data = _check(res, 'No se pudo subir la foto');
    return Escena360.fromJson(data['escena'] as Map<String, dynamic>);
  }

  Future<void> deleteEscena(String token, String recorridoId, int posicion) async {
    final res = await _client.delete(
      Uri.parse('$apiUrl/admin/recorridos/$recorridoId/escenas/$posicion'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _check(res, 'No se pudo quitar la foto');
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
