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
        estado: json['estado'] as String,
      );
}

class AuthUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? avatarUrl;
  final String? bio;
  final NegocioInfo? negocio;

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.bio,
    this.negocio,
  });

  bool get isNegocio => role == 'negocio';

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        bio: json['bio'] as String?,
        negocio: json['negocio'] != null ? NegocioInfo.fromJson(json['negocio'] as Map<String, dynamic>) : null,
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
