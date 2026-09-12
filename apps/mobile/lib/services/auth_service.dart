import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:4000/api',
);

// OBLIGATORIO: debe ser el Client ID WEB (el mismo GOOGLE_CLIENT_ID que usa
// apps/backend para verificar el idToken), NO el Client ID Android creado en
// Google Cloud Console para firmar el APK. Si se usa el Android aquí, el
// backend rechaza el token porque la audiencia no coincide.
const String _googleWebClientId =
    '794250368043-kd95m171jjljd9nvdhqv0cfi6qma3k6s.apps.googleusercontent.com';

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
  bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: _googleWebClientId);
    _googleSignInInitialized = true;
  }

  /// Inicia sesión con Google desde el celular y la intercambia por una
  /// sesión propia contra POST /api/auth/google/mobile.
  ///
  /// Devuelve null si el usuario canceló el selector de cuentas de Google.
  Future<AuthResponse?> signInWithGoogleMobile() async {
    await _ensureGoogleSignInInitialized();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw AuthError('No se pudo iniciar sesión con Google: ${e.description ?? e.code}');
    }

    final String? idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthError('No se pudo obtener el idToken de Google');
    }

    final res = await http.post(
      Uri.parse('$apiUrl/auth/google/mobile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    final data = _decode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthError((data['error'] as String?) ?? 'No se pudo completar la autenticación con Google');
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
