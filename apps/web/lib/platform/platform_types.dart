import '../services/auth_service.dart';

/// Lo único de la app que depende de dónde corre (navegador o teléfono). El
/// resto del código de `lib/` es Flutter puro y lo comparten web y móvil, así
/// que aquí no debe importarse `dart:html` ni ningún plugin de una plataforma.
abstract class KeyValueStore {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

/// Datos con los que el navegador vuelve del login con Google (van en la URL).
/// En móvil no hay redirección, así que siempre llega vacío.
class GoogleRedirectResult {
  final String? token;
  final String? error;
  final String? message;

  const GoogleRedirectResult({this.token, this.error, this.message});
}

abstract class GoogleLogin {
  /// Lee (y limpia de la URL) lo que dejó el redireccionamiento de Google.
  GoogleRedirectResult consumeRedirectResult();

  /// Web: redirige el navegador y devuelve null (la página se recarga).
  /// Móvil: abre el selector de cuentas y devuelve la sesión, o null si el
  /// usuario lo cancela.
  Future<AuthResponse?> start(AuthService authService);
}
