import '../services/auth_service.dart';

/// Lo único de la app que depende de dónde corre (navegador o teléfono). El
/// resto del código de `lib/` es Flutter puro y lo comparten web y móvil, así
/// que aquí no debe importarse `dart:html` ni ningún plugin de una plataforma.
abstract class KeyValueStore {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

abstract class GoogleLogin {
  /// Si esta pestaña es la ventana emergente que abrió [start] y ya volvió
  /// del login de Google, le entrega el resultado a quien la abrió (vía
  /// `postMessage`) y se cierra sola — devuelve `true` en ese caso, y quien
  /// llama no debe construir la app normal en esta pestaña. En móvil (no hay
  /// ventana emergente) siempre devuelve `false`.
  bool resolvePopupIfNeeded();

  /// Abre el selector de cuentas de Google (una ventana emergente en la web,
  /// el flujo nativo en móvil) y devuelve la sesión iniciada, o null si el
  /// usuario cierra la ventana/cancela sin elegir cuenta.
  Future<AuthResponse?> start(AuthService authService);
}
