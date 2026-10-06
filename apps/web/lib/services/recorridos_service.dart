import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/lugar.dart';
import 'auth_service.dart' show apiUrl, AuthError;

/// Un recorrido tiene de 1 a 32 escenarios. Mismo valor que `MAX_ESCENARIOS`
/// en el backend.
const maxEscenarios = 32;

/// Flecha dentro de un escenario que lleva a otro escenario del recorrido.
/// Ángulos en grados: [yaw] -180…180 (0 = centro de la foto), [pitch] -90…90
/// (0 = horizonte).
class Enlace360 {
  /// Casilla del escenario destino (1–32).
  final int destino;
  final double yaw;
  final double pitch;
  final String etiqueta;

  const Enlace360({required this.destino, required this.yaw, this.pitch = 0, this.etiqueta = ''});

  factory Enlace360.fromJson(Map<String, dynamic> json) => Enlace360(
        destino: (json['destino'] as num).toInt(),
        yaw: (json['yaw'] as num).toDouble(),
        pitch: (json['pitch'] as num?)?.toDouble() ?? 0,
        etiqueta: json['etiqueta'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'destino': destino, 'yaw': yaw, 'pitch': pitch, 'etiqueta': etiqueta};
}

/// Un escenario del recorrido: una foto 360° ya unida y optimizada por el
/// backend (JPG de máx. 4096×2048) más su miniatura, que es lo único que
/// carga el panel, y sus flechas hacia otros escenarios.
class Escena360 {
  final String id;
  /// Casilla: 1 = "Escenario 1" (el de entrada)… 32.
  final int posicion;
  /// Vacío = "Escenario N" (ver [nombre]).
  final String titulo;
  final String descripcion;
  /// Hacia dónde mira la cámara al entrar, en grados.
  final double yawInicial;
  final List<Enlace360> enlaces;
  final String imagenUrl;
  final String miniaturaUrl;
  final int ancho;
  final int alto;
  final int pesoBytes;

  const Escena360({
    required this.id,
    required this.posicion,
    this.titulo = '',
    this.descripcion = '',
    this.yawInicial = 0,
    this.enlaces = const [],
    required this.imagenUrl,
    required this.miniaturaUrl,
    required this.ancho,
    required this.alto,
    required this.pesoBytes,
  });

  factory Escena360.fromJson(Map<String, dynamic> json) => Escena360(
        id: json['id'] as String,
        posicion: (json['posicion'] as num).toInt(),
        titulo: json['titulo'] as String? ?? '',
        descripcion: json['descripcion'] as String? ?? '',
        yawInicial: (json['yawInicial'] as num?)?.toDouble() ?? 0,
        enlaces: ((json['enlaces'] as List?) ?? const [])
            .map((e) => Enlace360.fromJson(e as Map<String, dynamic>))
            .toList(),
        imagenUrl: json['imagenUrl'] as String,
        miniaturaUrl: json['miniaturaUrl'] as String,
        ancho: (json['ancho'] as num).toInt(),
        alto: (json['alto'] as num).toInt(),
        pesoBytes: (json['pesoBytes'] as num).toInt(),
      );

  String get nombre => titulo.isEmpty ? 'Escenario $posicion' : titulo;
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
  /// Pin propio del recorrido en el mapa (null = sin ubicación).
  final double? latitud;
  final double? longitud;
  final bool activo;
  final List<Escena360> escenas;

  const Recorrido360({
    required this.id,
    required this.nombre,
    required this.titulo,
    required this.texto,
    this.negocioId,
    this.negocioNombre,
    this.latitud,
    this.longitud,
    required this.activo,
    required this.escenas,
  });

  bool get tieneUbicacion => latitud != null && longitud != null;

  /// Lo que ve Unity: activo y con al menos un escenario (el endpoint público
  /// además oculta los de negocios sin aprobar).
  bool get publicado => activo && escenas.isNotEmpty;

  /// El escenario de una casilla (1–32), o null si todavía no se sube.
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
        latitud: latitud,
        longitud: longitud,
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
        latitud: (json['latitud'] as num?)?.toDouble(),
        longitud: (json['longitud'] as num?)?.toDouble(),
        activo: json['activo'] as bool? ?? true,
        escenas: ((json['escenas'] as List?) ?? const [])
            .map((e) => Escena360.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Flecha de un escenario publicado: lleva al escenario [destino] (su id).
class EnlacePublico {
  final String destino;
  final double yaw;
  final double pitch;
  final String etiqueta;

  const EnlacePublico({required this.destino, required this.yaw, this.pitch = 0, this.etiqueta = ''});

  factory EnlacePublico.fromJson(Map<String, dynamic> json) => EnlacePublico(
        destino: json['destino'] as String,
        yaw: (json['yaw'] as num).toDouble(),
        pitch: (json['pitch'] as num?)?.toDouble() ?? 0,
        etiqueta: json['etiqueta'] as String? ?? '',
      );
}

/// Escenario tal como lo publica `GET /api/recorridos` (el mismo JSON que
/// lee Unity, ver ModelosRecorrido.cs).
class EscenaPublica {
  final String id;
  final String titulo;
  final String descripcion;
  final String urlImagen;
  final String urlMiniatura;
  final double yawInicial;
  final List<EnlacePublico> enlaces;

  const EscenaPublica({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    required this.urlImagen,
    this.urlMiniatura = '',
    this.yawInicial = 0,
    this.enlaces = const [],
  });

  factory EscenaPublica.fromJson(Map<String, dynamic> json) => EscenaPublica(
        id: json['id'] as String? ?? json['urlImagen'] as String,
        titulo: json['titulo'] as String? ?? '',
        descripcion: json['descripcion'] as String? ?? '',
        urlImagen: json['urlImagen'] as String,
        urlMiniatura: json['urlMiniatura'] as String? ?? '',
        yawInicial: (json['yawInicial'] as num?)?.toDouble() ?? 0,
        enlaces: ((json['enlaces'] as List?) ?? const [])
            .map((e) => EnlacePublico.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Recorrido tal como lo publica `GET /api/recorridos` (el contrato con
/// Unity). Lo usan la ficha del lugar, el mapa y el visor 360° de la web.
class RecorridoPublico {
  final String nombre;
  final String textoParaMostrar;
  final String negocioId;
  final String urlPortada;
  final String escenaInicial;
  final List<EscenaPublica> escenas;
  /// Pin propio del recorrido (null = sin ubicación).
  final double? latitud;
  final double? longitud;

  const RecorridoPublico({
    required this.nombre,
    required this.textoParaMostrar,
    required this.negocioId,
    required this.urlPortada,
    this.latitud,
    this.longitud,
    this.escenaInicial = '',
    this.escenas = const [],
  });

  factory RecorridoPublico.fromJson(Map<String, dynamic> json) {
    final escenas = ((json['escenas'] as List?) ?? const [])
        .map((e) => EscenaPublica.fromJson(e as Map<String, dynamic>))
        .toList();
    return RecorridoPublico(
      nombre: json['nombre'] as String,
      textoParaMostrar: json['textoParaMostrar'] as String,
      negocioId: json['negocioId'] as String? ?? '',
      urlPortada: json['urlPortada'] as String? ?? '',
      latitud: json['tieneUbicacion'] == true ? (json['latitud'] as num).toDouble() : null,
      longitud: json['tieneUbicacion'] == true ? (json['longitud'] as num).toDouble() : null,
      escenaInicial: json['escenaInicial'] as String? ?? (escenas.isEmpty ? '' : escenas.first.id),
      escenas: escenas,
    );
  }

  bool get tieneUbicacion => latitud != null && longitud != null;

  /// El título que puso el admin (primera línea de [textoParaMostrar]).
  String get titulo => textoParaMostrar.split('\n').first.trim();

  /// La descripción (lo que va después del título).
  String get descripcion {
    final i = textoParaMostrar.indexOf('\n');
    return i < 0 ? '' : textoParaMostrar.substring(i + 1).trim();
  }
}

/// El recorrido 360° propio de un lugar, o `null` si todavía no tiene uno.
/// Nunca se cae a "cualquier otro recorrido": un lugar sin recorrido muestra
/// un aviso, no los de otros lugares. Cuenta como suyo si está ligado a ese
/// negocio ([lugarId] = negocioId) o si su nombre o título es el del lugar
/// ("playa_la_audiencia_360" o "Playa La Audiencia" ↔ "Playa La Audiencia").
RecorridoPublico? recorridoDeLugar(
  Iterable<RecorridoPublico> recorridos, {
  required String lugarId,
  required String lugarNombre,
}) {
  final porNegocio = recorridos.where((r) => r.negocioId.isNotEmpty && r.negocioId == lugarId);
  if (porNegocio.isNotEmpty) return porNegocio.first;

  final nombre = normalizarNombre(lugarNombre);
  if (nombre.isEmpty) return null;
  final porNombre = recorridos.where((r) =>
      normalizarNombre(r.nombre, esIdentificador: true) == nombre || normalizarNombre(r.titulo) == nombre);
  return porNombre.isEmpty ? null : porNombre.first;
}

/// Los recorridos con pin propio que no son de ningún lugar del mapa (FIME,
/// un mirador general) se muestran como un lugar más: su pin abre la tarjeta
/// con "Ver en 360°". Los que sí corresponden a un lugar ya están en el
/// mapa con el pin de ese lugar y no se duplican.
List<Lugar> lugaresDeRecorridos(Iterable<RecorridoPublico> recorridos, Iterable<Lugar> lugares) {
  return [
    for (final r in recorridos)
      if (r.tieneUbicacion &&
          r.escenas.isNotEmpty &&
          !lugares.any((l) => recorridoDeLugar([r], lugarId: l.id, lugarNombre: l.nombre) != null))
        Lugar(
          id: 'recorrido-${r.nombre}',
          nombre: r.titulo,
          categoriaTexto: 'Recorrido 360°',
          descripcion: r.descripcion,
          portada: r.urlPortada.isEmpty ? 'assets/images/hero-manzanillo.jpg' : r.urlPortada,
          ubicacion: Coordenadas(r.latitud!, r.longitud!),
          archivo360: r.urlPortada,
        ),
  ];
}

/// Aviso para un lugar que todavía no tiene recorrido 360°.
String sinRecorrido360(String lugarNombre) => '$lugarNombre todavía no cuenta con un recorrido 360°.';

/// Para comparar nombres de lugares: sin acentos, sin mayúsculas y sin el
/// "Playa" del inicio ("Playa La Audiencia" → "la audiencia"). Con
/// [esIdentificador] también convierte un `nombre` de recorrido
/// ("playa_la_audiencia_360") quitando guiones y el "360".
String normalizarNombre(String texto, {bool esIdentificador = false}) {
  const acentos = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  var t = texto.toLowerCase().split('').map((c) => acentos[c] ?? c).join();
  if (esIdentificador) {
    t = t.replaceAll(RegExp(r'[_-]+'), ' ').replaceAll(RegExp(r'\b360\b'), ' ');
  }
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.replaceAll(RegExp(r'^playa\s+'), '');
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
    double? latitud,
    double? longitud,
  }) async {
    final res = await _client.post(
      Uri.parse('$apiUrl/admin/recorridos'),
      headers: _jsonHeaders(token),
      body: jsonEncode({
        'nombre': nombre,
        'titulo': titulo,
        'texto': texto,
        'negocioId': negocioId,
        if (latitud != null && longitud != null) ...{'latitud': latitud, 'longitud': longitud},
      }),
    );
    final data = _check(res, 'No se pudo crear el recorrido');
    return Recorrido360.fromJson(data['recorrido'] as Map<String, dynamic>);
  }

  /// `fields` acepta: nombre, titulo, texto, negocioId, activo, latitud y
  /// longitud (juntas; null en las dos quita el pin).
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

  /// Sube (o reemplaza) la foto de una casilla: `posicion` 1 = "Escenario 1"…
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

  /// `fields` acepta: titulo, descripcion, yawInicial.
  Future<Escena360> updateEscena(String token, String recorridoId, int posicion, Map<String, dynamic> fields) async {
    final res = await _client.patch(
      Uri.parse('$apiUrl/admin/recorridos/$recorridoId/escenas/$posicion'),
      headers: _jsonHeaders(token),
      body: jsonEncode(fields),
    );
    final data = _check(res, 'No se pudo actualizar el escenario');
    return Escena360.fromJson(data['escena'] as Map<String, dynamic>);
  }

  /// Reemplaza todas las flechas del escenario (lista vacía = sin flechas).
  Future<Escena360> setEnlaces(String token, String recorridoId, int posicion, List<Enlace360> enlaces) async {
    final res = await _client.put(
      Uri.parse('$apiUrl/admin/recorridos/$recorridoId/escenas/$posicion/enlaces'),
      headers: _jsonHeaders(token),
      body: jsonEncode({'enlaces': enlaces.map((e) => e.toJson()).toList()}),
    );
    final data = _check(res, 'No se pudieron guardar las flechas');
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
