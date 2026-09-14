import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:4000/api',
);

class NegocioInfo {
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
  final String estado;

  const NegocioInfo({
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
    required this.estado,
  });

  bool get aprobado => estado == 'aprobado';
  bool get pendiente => estado == 'pendiente';
  bool get rechazado => estado == 'rechazado';

  factory NegocioInfo.fromJson(Map<String, dynamic> json) => NegocioInfo(
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
        estado: json['estado'] as String,
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
  final NegocioInfo? negocio;

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.activo = true,
    this.avatarUrl,
    this.bio,
    this.negocio,
  });

  bool get isNegocio => role == 'negocio';
  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        activo: json['activo'] as bool? ?? true,
        avatarUrl: json['avatarUrl'] as String?,
        bio: json['bio'] as String?,
        negocio: json['negocio'] != null ? NegocioInfo.fromJson(json['negocio'] as Map<String, dynamic>) : null,
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
  final String nombre;
  final String? categoria;
  final String estado;
  final String email;
  final String contacto;
  final DateTime solicitadoEn;
  final String? archivo360;
  final String? arMarcador;
  final String? arGeo;

  const NegocioSummary({
    required this.id,
    required this.nombre,
    this.categoria,
    required this.estado,
    required this.email,
    required this.contacto,
    required this.solicitadoEn,
    this.archivo360,
    this.arMarcador,
    this.arGeo,
  });

  bool get pendiente => estado == 'pendiente';
  bool get aprobado => estado == 'aprobado';
  bool get rechazado => estado == 'rechazado';

  factory NegocioSummary.fromJson(Map<String, dynamic> json) => NegocioSummary(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        categoria: json['categoria'] as String?,
        estado: json['estado'] as String? ?? 'pendiente',
        email: json['email'] as String,
        contacto: json['contacto'] as String,
        solicitadoEn: DateTime.parse(json['solicitadoEn'] as String),
        archivo360: json['archivo360'] as String?,
        arMarcador: json['arMarcador'] as String?,
        arGeo: json['arGeo'] as String?,
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
  const AuthError(this.message);

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
      throw AuthError((data['error'] as String?) ?? 'No se pudo obtener la sesión');
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

  Future<AuthUser> uploadGaleriaImage(String token, Uint8List bytes, String filename) async {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'jpg';
    final subtype = ext == 'jpg' ? 'jpeg' : ext;

    final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/auth/profile/galeria'))
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

  Future<AuthUser> deleteGaleriaImage(String token, String url) async {
    final request = http.Request('DELETE', Uri.parse('$apiUrl/auth/profile/galeria'))
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

  Future<void> adminApproveNegocio(String token, String userId) {
    return _post('/admin/negocios/$userId/aprobar', token);
  }

  Future<void> adminRejectNegocio(String token, String userId) {
    return _post('/admin/negocios/$userId/rechazar', token);
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
