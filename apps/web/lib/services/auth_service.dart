import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Dirección de la API. En la web es `/api` en el mismo sitio donde se abrió
/// (http://localhost:5173 en desarrollo, el dominio en producción), así no
/// depende de ningún puerto. La app móvil la recibe completa con
/// `--dart-define=API_URL=http://<IP-de-la-PC>:5173/api` (scripts/mobile-dev.js).
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: '/api');

class NegocioInfo {
  final String id;
  final String nombre;
  final String? categoria;
  final String? descripcion;
  final String? direccion;
  final String? telefono;
  final String? sitioWeb;
  final String? horario;
  final String? portada;
  final List<String> galeria;
  final String? archivo360;
  final String? arMarcador;
  final String? arGeo;
  final double? latitud;
  final double? longitud;
  final String estado;
  final DateTime createdAt;

  const NegocioInfo({
    required this.id,
    required this.nombre,
    this.categoria,
    this.descripcion,
    this.direccion,
    this.telefono,
    this.sitioWeb,
    this.horario,
    this.portada,
    this.galeria = const [],
    this.archivo360,
    this.arMarcador,
    this.arGeo,
    this.latitud,
    this.longitud,
    required this.estado,
    required this.createdAt,
  });

  bool get aprobado => estado == 'aprobado';
  bool get pendiente => estado == 'pendiente';
  bool get rechazado => estado == 'rechazado';

  factory NegocioInfo.fromJson(Map<String, dynamic> json) => NegocioInfo(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        categoria: json['categoria'] as String?,
        descripcion: json['descripcion'] as String?,
        direccion: json['direccion'] as String?,
        telefono: json['telefono'] as String?,
        sitioWeb: json['sitioWeb'] as String?,
        horario: json['horario'] as String?,
        portada: json['portada'] as String?,
        galeria: (json['galeria'] as List?)?.cast<String>() ?? const [],
        archivo360: json['archivo360'] as String?,
        arMarcador: json['arMarcador'] as String?,
        arGeo: json['arGeo'] as String?,
        latitud: (json['latitud'] as num?)?.toDouble(),
        longitud: (json['longitud'] as num?)?.toDouble(),
        estado: json['estado'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class AuthUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final bool activo;
  final String? avatarUrl;
  final String? bio;
  final List<NegocioInfo> negocios;

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.activo = true,
    this.avatarUrl,
    this.bio,
    this.negocios = const [],
  });

  bool get isNegocio => role == 'negocio';
  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';
  List<NegocioInfo> get negociosAprobados => negocios.where((n) => n.aprobado).toList();

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        activo: json['activo'] as bool? ?? true,
        avatarUrl: json['avatarUrl'] as String?,
        bio: json['bio'] as String?,
        negocios: (json['negocios'] as List?)?.map((n) => NegocioInfo.fromJson(n as Map<String, dynamic>)).toList() ?? const [],
      );
}

class AdminAccount {
  final String id;
  final String email;
  final String name;
  final String role;
  final DateTime createdAt;

  const AdminAccount({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  bool get isSuperAdmin => role == 'super_admin';

  factory AdminAccount.fromJson(Map<String, dynamic> json) => AdminAccount(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class NegocioSummary {
  final String id;
  final String? ownerId;
  final String nombre;
  final String? categoria;
  final String? descripcion;
  final String? direccion;
  final String estado;
  final String email;
  final String contacto;
  final DateTime solicitadoEn;
  final String? archivo360;
  final String? arMarcador;
  final String? arGeo;
  final bool esAdicional;
  final String? portada;
  /// Pin del lugar en el mapa público (null = no aparece en el mapa).
  final double? latitud;
  final double? longitud;

  const NegocioSummary({
    required this.id,
    this.ownerId,
    required this.nombre,
    this.categoria,
    this.descripcion,
    this.direccion,
    required this.estado,
    required this.email,
    required this.contacto,
    required this.solicitadoEn,
    this.archivo360,
    this.arMarcador,
    this.arGeo,
    this.esAdicional = false,
    this.portada,
    this.latitud,
    this.longitud,
  });

  bool get tieneUbicacion => latitud != null && longitud != null;

  bool get pendiente => estado == 'pendiente';
  bool get aprobado => estado == 'aprobado';
  bool get rechazado => estado == 'rechazado';

  factory NegocioSummary.fromJson(Map<String, dynamic> json) => NegocioSummary(
        id: json['id'] as String,
        ownerId: json['ownerId'] as String?,
        nombre: json['nombre'] as String,
        categoria: json['categoria'] as String?,
        descripcion: json['descripcion'] as String?,
        direccion: json['direccion'] as String?,
        estado: json['estado'] as String? ?? 'pendiente',
        email: json['email'] as String,
        contacto: json['contacto'] as String,
        solicitadoEn: DateTime.parse(json['solicitadoEn'] as String),
        archivo360: json['archivo360'] as String?,
        arMarcador: json['arMarcador'] as String?,
        arGeo: json['arGeo'] as String?,
        esAdicional: json['esAdicional'] as bool? ?? false,
        portada: json['portada'] as String?,
        latitud: (json['latitud'] as num?)?.toDouble(),
        longitud: (json['longitud'] as num?)?.toDouble(),
      );
}

/// Marcador de RA o recorrido 360 ya ligado a un negocio (resumen para el
/// detalle de la solicitud en el panel admin).
class ContenidoLigado {
  final String id;
  final String nombre;
  final String titulo;
  final bool activo;

  const ContenidoLigado({required this.id, required this.nombre, required this.titulo, required this.activo});

  factory ContenidoLigado.fromJson(Map<String, dynamic> json) => ContenidoLigado(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        titulo: json['titulo'] as String? ?? '',
        activo: json['activo'] as bool? ?? true,
      );
}

/// Todo lo que el admin ve (y puede editar) de una solicitud de negocio:
/// los datos que mandó la empresa desde su panel, el dueño y el contenido de
/// realidad aumentada / recorridos 360 que ya tiene ligado.
class NegocioDetalle {
  final String id;
  final String nombre;
  final String? categoria;
  final String? descripcion;
  final String? direccion;
  final String? telefono;
  final String? sitioWeb;
  final String? horario;
  final String? portada;
  final double? latitud;
  final double? longitud;
  final String estado;
  final String email;
  final String contacto;
  final DateTime solicitadoEn;
  final List<ContenidoLigado> marcadores;
  final List<ContenidoLigado> recorridos;

  const NegocioDetalle({
    required this.id,
    required this.nombre,
    this.categoria,
    this.descripcion,
    this.direccion,
    this.telefono,
    this.sitioWeb,
    this.horario,
    this.portada,
    this.latitud,
    this.longitud,
    required this.estado,
    required this.email,
    required this.contacto,
    required this.solicitadoEn,
    this.marcadores = const [],
    this.recorridos = const [],
  });

  bool get pendiente => estado == 'pendiente';
  bool get aprobado => estado == 'aprobado';
  bool get rechazado => estado == 'rechazado';
  bool get tieneUbicacion => latitud != null && longitud != null;

  factory NegocioDetalle.fromJson(Map<String, dynamic> json) => NegocioDetalle(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        categoria: json['categoria'] as String?,
        descripcion: json['descripcion'] as String?,
        telefono: json['telefono'] as String?,
        sitioWeb: json['sitioWeb'] as String?,
        horario: json['horario'] as String?,
        portada: json['portada'] as String?,
        latitud: (json['latitud'] as num?)?.toDouble(),
        longitud: (json['longitud'] as num?)?.toDouble(),
        estado: json['estado'] as String? ?? 'pendiente',
        email: json['email'] as String? ?? '',
        contacto: json['contacto'] as String? ?? '',
        solicitadoEn: DateTime.parse(json['solicitadoEn'] as String),
        marcadores: ((json['marcadores'] as List?) ?? const [])
            .map((m) => ContenidoLigado.fromJson(m as Map<String, dynamic>))
            .toList(),
        recorridos: ((json['recorridos'] as List?) ?? const [])
            .map((r) => ContenidoLigado.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
}

class AppNotification {
  final String id;
  final String tipo;
  final String titulo;
  final String cuerpo;
  final String? negocioId;
  final bool leida;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.cuerpo,
    this.negocioId,
    required this.leida,
    required this.createdAt,
  });

  AppNotification copyWith({bool? leida}) => AppNotification(
        id: id,
        tipo: tipo,
        titulo: titulo,
        cuerpo: cuerpo,
        negocioId: negocioId,
        leida: leida ?? this.leida,
        createdAt: createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        tipo: json['tipo'] as String,
        titulo: json['titulo'] as String,
        cuerpo: json['cuerpo'] as String,
        negocioId: json['negocioId'] as String?,
        leida: json['leida'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class AdminStats {
  final int turistas;
  final int negociosActivos;
  final int negociosPendientes;
  final int negociosTotal;

  const AdminStats({
    required this.turistas,
    required this.negociosActivos,
    required this.negociosPendientes,
    required this.negociosTotal,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        turistas: json['turistas'] as int,
        negociosActivos: json['negociosActivos'] as int,
        negociosPendientes: json['negociosPendientes'] as int,
        negociosTotal: json['negociosTotal'] as int,
      );
}

class AuthResponse {
  final String token;
  final AuthUser user;

  const AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'] as String,
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class AuthError implements Exception {
  final String message;
  final String? code;
  const AuthError(this.message, {this.code});

  bool get isBlocked => code == 'blocked';

  @override
  String toString() => message;
}

class AuthService {
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  String get googleLoginUrl => '$apiUrl/auth/google';

  Future<AuthResponse> login(String email, String password) {
    return _postCredentials('/auth/login', {
      'email': email,
      'password': password,
    });
  }

  Future<AuthResponse> register(
    String email,
    String password,
    String name, {
    String rol = 'turista',
    String? categoria,
  }) {
    return _postCredentials('/auth/register', {
      'email': email,
      'password': password,
      'name': name,
      'rol': rol,
      if (categoria != null && categoria.trim().isNotEmpty) 'categoria': categoria,
    });
  }

  Future<AuthUser> getCurrentUser(String token) async {
    final res = await _client.get(
      Uri.parse('$apiUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = _decode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo obtener la sesión', code: data['code'] as String?);
    }

    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AuthUser> uploadAvatar(String token, Uint8List bytes, String filename) async {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
    final subtype = ext == 'jpg' ? 'jpeg' : ext;

    final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/auth/profile/avatar'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType('image', subtype),
      ));

    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    final data = _decode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo subir la imagen');
    }

    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AuthUser> uploadGaleriaImage(String token, String negocioId, Uint8List bytes, String filename) async {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
    final subtype = ext == 'jpg' ? 'jpeg' : ext;

    final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/auth/profile/negocios/$negocioId/galeria'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType('image', subtype),
      ));

    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    final data = _decode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo subir la imagen');
    }

    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AuthUser> deleteGaleriaImage(String token, String negocioId, String url) async {
    final request = http.Request('DELETE', Uri.parse('$apiUrl/auth/profile/negocios/$negocioId/galeria'))
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'url': url});

    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    final data = _decode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo eliminar la imagen');
    }

    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AuthUser> uploadNegocioPortada(String token, String negocioId, Uint8List bytes, String filename) async {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
    final subtype = ext == 'jpg' ? 'jpeg' : ext;

    final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/auth/profile/negocios/$negocioId/avatar'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType('image', subtype),
      ));

    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    final data = _decode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo subir la imagen');
    }

    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AuthUser> updateProfile(String token, Map<String, String> fields) async {
    final res = await _client.patch(
      Uri.parse('$apiUrl/auth/profile'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(fields),
    );

    final data = _decode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo actualizar el perfil');
    }

    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// `fields`: textos del negocio y, opcionales, `latitud`/`longitud` (números,
  /// juntos; null los quita).
  Future<AuthUser> updateNegocio(String token, String negocioId, Map<String, Object?> fields) async {
    final res = await _client.patch(
      Uri.parse('$apiUrl/auth/profile/negocios/$negocioId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(fields),
    );

    final data = _decode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo actualizar el negocio');
    }

    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AuthUser> createNegocioSuggestion(
    String token, {
    required String nombre,
    String? categoria,
    String? descripcion,
    String? direccion,
    String? telefono,
    String? horario,
    String? sitioWeb,
    double? latitud,
    double? longitud,
  }) async {
    bool lleno(String? v) => v != null && v.trim().isNotEmpty;
    final res = await _client.post(
      Uri.parse('$apiUrl/auth/profile/negocios'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'nombre': nombre,
        if (lleno(categoria)) 'categoria': categoria,
        if (lleno(descripcion)) 'descripcion': descripcion,
        if (lleno(direccion)) 'direccion': direccion,
        if (lleno(telefono)) 'telefono': telefono,
        if (lleno(horario)) 'horario': horario,
        if (lleno(sitioWeb)) 'sitioWeb': sitioWeb,
        if (latitud != null && longitud != null) ...{'latitud': latitud, 'longitud': longitud},
      }),
    );

    final data = _decode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo enviar la sugerencia');
    }

    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AdminStats> adminGetStats(String token) async {
    final data = await _get('/admin/dashboard', token);
    return AdminStats.fromJson(data['stats'] as Map<String, dynamic>);
  }

  Future<List<AuthUser>> adminListUsers(String token) async {
    final data = await _get('/admin/users', token);
    return (data['users'] as List).map((u) => AuthUser.fromJson(u as Map<String, dynamic>)).toList();
  }

  Future<AuthUser> adminSetUserActive(String token, String userId, bool activo) async {
    final data = await _patch('/admin/users/$userId/activo', token, {'activo': activo});
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<List<NegocioSummary>> adminListNegocios(String token) async {
    final data = await _get('/admin/negocios', token);
    return (data['negocios'] as List).map((n) => NegocioSummary.fromJson(n as Map<String, dynamic>)).toList();
  }

  Future<List<NegocioSummary>> adminListNegociosPendientes(String token) async {
    final data = await _get('/admin/negocios/pendientes', token);
    return (data['negocios'] as List).map((n) => NegocioSummary.fromJson(n as Map<String, dynamic>)).toList();
  }

  Future<NegocioDetalle> adminGetNegocio(String token, String negocioId) async {
    final data = await _get('/admin/negocios/$negocioId', token);
    return NegocioDetalle.fromJson(data['negocio'] as Map<String, dynamic>);
  }

  /// Guarda lo que el admin corrigió de una solicitud (el mismo PATCH que
  /// [adminActualizarLugar]) y devuelve el detalle completo ya actualizado.
  /// [fields] admite `null` en los textos opcionales para borrarlos.
  Future<NegocioDetalle> adminUpdateNegocio(String token, String negocioId, Map<String, dynamic> fields) async {
    await _patch('/admin/negocios/$negocioId', token, fields);
    return adminGetNegocio(token, negocioId);
  }

  Future<NegocioDetalle> adminUploadNegocioPortada(String token, String negocioId, Uint8List bytes, String filename) async {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
    final subtype = ext == 'jpg' ? 'jpeg' : ext;

    final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/admin/negocios/$negocioId/portada'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType('image', subtype),
      ));

    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    final data = _decode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo subir la imagen');
    }

    return NegocioDetalle.fromJson(data['negocio'] as Map<String, dynamic>);
  }

  /// Registra un lugar sin dueño desde "Mapa y RA" (una facultad, un
  /// mirador…): queda aprobado y a nombre del super admin. `datos`: nombre,
  /// categoria, descripcion, direccion, latitud, longitud.
  Future<NegocioSummary> adminCrearLugar(String token, Map<String, dynamic> datos) async {
    final data = await _postJson('/admin/lugares', token, datos);
    return NegocioSummary.fromJson(data['negocio'] as Map<String, dynamic>);
  }

  /// Corrige los datos de cualquier lugar (los mismos campos que [adminCrearLugar]).
  Future<NegocioSummary> adminActualizarLugar(String token, String negocioId, Map<String, dynamic> datos) async {
    final data = await _patch('/admin/negocios/$negocioId', token, datos);
    return NegocioSummary.fromJson(data['negocio'] as Map<String, dynamic>);
  }

  /// Borra un lugar con sus recorridos 360° y marcadores.
  Future<void> adminEliminarLugar(String token, String negocioId) async {
    final res = await _client.delete(
      Uri.parse('$apiUrl/admin/negocios/$negocioId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final data = _decode(res.body);
      throw AuthError((data['error'] as String?) ?? 'No se pudo eliminar el lugar');
    }
  }

  Future<void> adminApproveNegocio(String token, String negocioId) {
    return _post('/admin/negocios/$negocioId/aprobar', token);
  }

  Future<void> adminRejectNegocio(String token, String negocioId) {
    return _post('/admin/negocios/$negocioId/rechazar', token);
  }

  Future<List<AppNotification>> listNotifications(String token) async {
    final data = await _get('/notifications', token);
    return (data['notifications'] as List).map((n) => AppNotification.fromJson(n as Map<String, dynamic>)).toList();
  }

  Future<int> unreadNotificationCount(String token) async {
    final data = await _get('/notifications/unread-count', token);
    return data['count'] as int;
  }

  Future<void> markNotificationRead(String token, String id) {
    return _post('/notifications/$id/leer', token);
  }

  Future<void> markAllNotificationsRead(String token) {
    return _post('/notifications/leer-todas', token);
  }

  Future<List<AdminAccount>> adminListAdmins(String token) async {
    final data = await _get('/admin/admins', token);
    return (data['admins'] as List).map((a) => AdminAccount.fromJson(a as Map<String, dynamic>)).toList();
  }

  Future<AdminAccount> adminCreateAdmin(String token, {required String email, required String password, required String nombres}) async {
    final data = await _postJson('/admin/admins', token, {
      'email': email,
      'password': password,
      'nombres': nombres,
    });
    return AdminAccount.fromJson(data['admin'] as Map<String, dynamic>);
  }

  Future<void> adminDeleteAdmin(String token, String adminId) async {
    final res = await _client.delete(
      Uri.parse('$apiUrl/admin/admins/$adminId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final data = _decode(res.body);
      throw AuthError((data['error'] as String?) ?? 'No se pudo eliminar al administrador');
    }
  }

  Future<Map<String, dynamic>> _get(String path, String token) async {
    final res = await _client.get(
      Uri.parse('$apiUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo completar la solicitud');
    }
    return data;
  }

  Future<Map<String, dynamic>> _patch(String path, String token, Map<String, dynamic> body) async {
    final res = await _client.patch(
      Uri.parse('$apiUrl$path'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(body),
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo completar la solicitud');
    }
    return data;
  }

  Future<void> _post(String path, String token) async {
    final res = await _client.post(
      Uri.parse('$apiUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final data = _decode(res.body);
      throw AuthError((data['error'] as String?) ?? 'No se pudo completar la solicitud');
    }
  }

  Future<Map<String, dynamic>> _postJson(String path, String token, Map<String, dynamic> body) async {
    final res = await _client.post(
      Uri.parse('$apiUrl$path'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(body),
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo completar la solicitud');
    }
    return data;
  }

  Future<AuthResponse> _postCredentials(String path, Map<String, String> body) async {
    final res = await _client.post(
      Uri.parse('$apiUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final data = _decode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo completar la solicitud');
    }

    return AuthResponse.fromJson(data);
  }

  Map<String, dynamic> _decode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
