import 'dart:async';
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touristmar_web/platform/platform_services.dart';
import 'package:touristmar_web/services/auth_service.dart';

// Debe ser el Client ID *Web* (el mismo GOOGLE_CLIENT_ID del backend), no el de
// Android: el backend valida el idToken contra ese y rechaza cualquier otro.
const String _googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '794250368043-kd95m171jjljd9nvdhqv0cfi6qma3k6s.apps.googleusercontent.com',
);

Future<void> installMobilePlatform() async {
  final prefs = await SharedPreferences.getInstance();
  PlatformServices.store = PrefsKeyValueStore(prefs);
  PlatformServices.googleLogin = MobileGoogleLogin();
}

class PrefsKeyValueStore implements KeyValueStore {
  final SharedPreferences _prefs;

  PrefsKeyValueStore(this._prefs);

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  void write(String key, String value) => unawaited(_prefs.setString(key, value));

  @override
  void remove(String key) => unawaited(_prefs.remove(key));
}

class MobileGoogleLogin implements GoogleLogin {
  bool _initialized = false;

  @override
  GoogleRedirectResult consumeRedirectResult() => const GoogleRedirectResult();

  @override
  Future<AuthResponse?> start(AuthService authService) async {
    if (!_initialized) {
      await GoogleSignIn.instance.initialize(serverClientId: _googleWebClientId);
      _initialized = true;
    }

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthError('No se pudo iniciar sesión con Google: ${e.description ?? e.code.name}');
    }

    final idToken = account.authentication.idToken;
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
      throw AuthError(
        (data['error'] as String?) ?? 'No se pudo completar la autenticación con Google',
        code: data['code'] as String?,
      );
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
