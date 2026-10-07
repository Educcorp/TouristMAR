import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart' show apiUrl;
import 'session_storage.dart';

/// Reseñas de los lugares (`/api/resenas`), compartidas por web y móvil. Solo
/// los negocios reales tienen reseñas (los lugares de ejemplo no existen en
/// la base de datos), ver `Lugar.esFavoritable`.

class ResenasError implements Exception {
  final String message;
  const ResenasError(this.message);

  @override
  String toString() => message;
}

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// "8 sep 2026", como se muestran las fechas en el resto de la app.
String fechaCorta(DateTime fecha) {
  final f = fecha.toLocal();
  return '${f.day} ${_meses[f.month - 1]} ${f.year}';
}

String inicialesDe(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  final primera = partes.first[0];
  final segunda = partes.length > 1 ? partes[1][0] : '';
  return (primera + segunda).toUpperCase();
}

class ResumenResenas {
  final double promedio;
  final int total;

  /// `porEstrellas[i]` = cuántas reseñas tienen `i + 1` estrellas.
  final List<int> porEstrellas;

  const ResumenResenas({this.promedio = 0, this.total = 0, this.porEstrellas = const [0, 0, 0, 0, 0]});

  factory ResumenResenas.fromJson(Map<String, dynamic> json) => ResumenResenas(
        promedio: (json['promedio'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        porEstrellas: ((json['porEstrellas'] as List?) ?? const [0, 0, 0, 0, 0]).map((e) => (e as num).toInt()).toList(),
      );

  /// Porcentaje (0-100) de reseñas con [estrellas] estrellas.
  int porcentaje(int estrellas) => total == 0 ? 0 : (porEstrellas[estrellas - 1] * 100 / total).round();
}

class Resena {
  final String id;
  final int estrellas;
  final String? comentario;
  final String? respuesta;
  final DateTime? respuestaEn;
  final DateTime createdAt;
  final String autorNombre;
  final String? autorAvatarUrl;

  /// La reseña del usuario que está viendo la lista.
  final bool mia;

  const Resena({
    required this.id,
    required this.estrellas,
    this.comentario,
    this.respuesta,
    this.respuestaEn,
    required this.createdAt,
    required this.autorNombre,
    this.autorAvatarUrl,
    this.mia = false,
  });

  factory Resena.fromJson(Map<String, dynamic> json) {
    final autor = (json['autor'] as Map<String, dynamic>?) ?? const {};
    return Resena(
      id: json['id'] as String,
      estrellas: (json['estrellas'] as num).toInt(),
      comentario: json['comentario'] as String?,
      respuesta: json['respuesta'] as String?,
      respuestaEn: json['respuestaEn'] == null ? null : DateTime.tryParse(json['respuestaEn'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      autorNombre: (autor['nombre'] as String?) ?? 'Visitante',
      autorAvatarUrl: autor['avatarUrl'] as String?,
      mia: json['mia'] == true,
    );
  }

  String get fecha => fechaCorta(createdAt);
}

class ResenasLugar {
  final ResumenResenas resumen;
  final List<Resena> resenas;

  const ResenasLugar({required this.resumen, required this.resenas});

  Resena? get mia {
    for (final r in resenas) {
      if (r.mia) return r;
    }
    return null;
  }
}

/// Una reseña del propio usuario, con el lugar al que pertenece.
class MiResena {
  final String id;
  final int estrellas;
  final String? comentario;
  final String? respuesta;
  final DateTime createdAt;
  final String lugarId;
  final String lugarNombre;

  const MiResena({
    required this.id,
    required this.estrellas,
    this.comentario,
    this.respuesta,
    required this.createdAt,
    required this.lugarId,
    required this.lugarNombre,
  });

  factory MiResena.fromJson(Map<String, dynamic> json) {
    final lugar = json['lugar'] as Map<String, dynamic>;
    return MiResena(
      id: json['id'] as String,
      estrellas: (json['estrellas'] as num).toInt(),
      comentario: json['comentario'] as String?,
      respuesta: json['respuesta'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lugarId: lugar['id'] as String,
      lugarNombre: lugar['nombre'] as String,
    );
  }

  String get fecha => fechaCorta(createdAt);
}

/// Una reseña vista desde el panel de administración.
class ResenaAdmin {
  final String id;
  final int estrellas;
  final String? comentario;
  final String? respuesta;
  final DateTime createdAt;
  final String autorNombre;
  final String autorEmail;
  final String lugarId;
  final String lugarNombre;

  const ResenaAdmin({
    required this.id,
    required this.estrellas,
    this.comentario,
    this.respuesta,
    required this.createdAt,
    required this.autorNombre,
    required this.autorEmail,
    required this.lugarId,
    required this.lugarNombre,
  });

  factory ResenaAdmin.fromJson(Map<String, dynamic> json) {
    final autor = json['autor'] as Map<String, dynamic>;
    final lugar = json['lugar'] as Map<String, dynamic>;
    return ResenaAdmin(
      id: json['id'] as String,
      estrellas: (json['estrellas'] as num).toInt(),
      comentario: json['comentario'] as String?,
      respuesta: json['respuesta'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      autorNombre: autor['nombre'] as String,
      autorEmail: autor['email'] as String,
      lugarId: lugar['id'] as String,
      lugarNombre: lugar['nombre'] as String,
    );
  }

  String get fecha => fechaCorta(createdAt);
}

class ResenasService {
  final http.Client _client;

  ResenasService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (SessionStorage.token != null) 'Authorization': 'Bearer ${SessionStorage.token}',
      };

  /// Reseñas de un lugar con su resumen. Público; con sesión marca la propia.
  Future<ResenasLugar> listarDeLugar(String lugarId) async {
    final data = await _send(() => _client.get(Uri.parse('$apiUrl/resenas/lugar/$lugarId'), headers: _headers));
    return ResenasLugar(
      resumen: ResumenResenas.fromJson(data['resumen'] as Map<String, dynamic>),
      resenas: (data['resenas'] as List).map((j) => Resena.fromJson(j as Map<String, dynamic>)).toList(),
    );
  }

  /// Crea o edita la reseña del usuario sobre [lugarId] (una por lugar).
  Future<void> guardar(String lugarId, {required int estrellas, String? comentario}) async {
    await _send(() => _client.put(
          Uri.parse('$apiUrl/resenas/lugar/$lugarId'),
          headers: _headers,
          body: jsonEncode({'estrellas': estrellas, 'comentario': comentario}),
        ));
  }

  Future<void> borrar(String lugarId) async {
    await _send(() => _client.delete(Uri.parse('$apiUrl/resenas/lugar/$lugarId'), headers: _headers));
  }

  Future<List<MiResena>> mias() async {
    final data = await _send(() => _client.get(Uri.parse('$apiUrl/resenas/mias'), headers: _headers));
    return (data['resenas'] as List).map((j) => MiResena.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// El dueño del negocio responde (o edita su respuesta).
  Future<void> responder(String resenaId, String respuesta) async {
    await _send(() => _client.put(
          Uri.parse('$apiUrl/resenas/$resenaId/respuesta'),
          headers: _headers,
          body: jsonEncode({'respuesta': respuesta}),
        ));
  }

  Future<void> quitarRespuesta(String resenaId) async {
    await _send(() => _client.delete(Uri.parse('$apiUrl/resenas/$resenaId/respuesta'), headers: _headers));
  }

  Future<List<ResenaAdmin>> adminListar() async {
    final data = await _send(() => _client.get(Uri.parse('$apiUrl/admin/resenas'), headers: _headers));
    return (data['resenas'] as List).map((j) => ResenaAdmin.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> adminBorrar(String resenaId) async {
    await _send(() => _client.delete(Uri.parse('$apiUrl/admin/resenas/$resenaId'), headers: _headers));
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() request) async {
    final http.Response res;
    try {
      res = await request();
    } catch (_) {
      throw const ResenasError('No se pudo conectar con el servidor');
    }
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ResenasError((data['error'] as String?) ?? 'No se pudo completar la solicitud');
    }
    return data;
  }

  Map<String, dynamic> _decode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
