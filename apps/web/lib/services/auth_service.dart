import 'dart:convert';
import 'package:http/http.dart' as http;

const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:4000/api',
);

class AuthUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? avatarUrl;

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.avatarUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        avatarUrl: json['avatarUrl'] as String?,
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

  Future<AuthResponse> register(String email, String password, String name) {
    return _postCredentials('/auth/register', {
      'email': email,
      'password': password,
      'name': name,
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
