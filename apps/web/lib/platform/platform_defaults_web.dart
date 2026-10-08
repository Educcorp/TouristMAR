// Este archivo solo se importa en la build web (import condicional en
// platform_services.dart), así que usar las APIs del navegador aquí es
// correcto. Migrado de `dart:html` (obsoleto) a `package:web`.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../services/auth_service.dart';
import 'platform_types.dart';

KeyValueStore createDefaultStore() => _LocalStorageStore();

GoogleLogin createDefaultGoogleLogin() => _PopupGoogleLogin();

class _LocalStorageStore implements KeyValueStore {
  @override
  String? read(String key) => web.window.localStorage.getItem(key);

  @override
  void write(String key, String value) => web.window.localStorage.setItem(key, value);

  @override
  void remove(String key) => web.window.localStorage.removeItem(key);
}

/// Identifica, en el `postMessage` entre la ventana emergente y la pestaña
/// que la abrió, que se trata del resultado del login con Google (y no de
/// cualquier otro mensaje que el navegador pudiera entregar a ese handler).
const _mensajeGoogleLogin = 'touristmar-google-login';

/// Login con Google en la web, en una ventana emergente en vez de redirigir
/// la pestaña principal.
///
/// Antes `start()` hacía `window.location.href = ...`, lo que dejaba
/// accounts.google.com (y el salto de vuelta por el backend) metidos en el
/// historial real del navegador de esa pestaña. Como esas páginas son de
/// otro origen, la app nunca puede reescribir ni saltarse esas entradas una
/// vez creadas — así que con cualquier cuenta, incluso una que nunca usó
/// Google, el botón "atrás" podía terminar en el selector de cuentas de
/// Google en vez de volver dentro de la app (y de ahí, en un bucle). Con una
/// ventana aparte, esas páginas viven y mueren en esa ventana: la pestaña
/// principal nunca las visita y su historial nunca se ensucia.
class _PopupGoogleLogin implements GoogleLogin {
  @override
  bool resolvePopupIfNeeded() {
    final opener = web.window.opener;
    final uri = Uri.base;
    final tieneResultado = uri.queryParameters.containsKey('token') || uri.queryParameters.containsKey('error');
    if (opener == null || !tieneResultado) return false;

    final payload = jsonEncode({
      'type': _mensajeGoogleLogin,
      'token': uri.queryParameters['token'],
      'error': uri.queryParameters['error'],
      'message': uri.queryParameters['message'],
    });
    (opener as web.Window).postMessage(payload.toJS, web.window.location.origin.toJS);
    web.window.close();
    return true;
  }

  @override
  Future<AuthResponse?> start(AuthService authService) async {
    final popup = web.window.open(authService.googleLoginUrl, 'touristmar-google-login', 'width=480,height=680');
    if (popup == null) {
      throw const AuthError('El navegador bloqueó la ventana de Google. Permite ventanas emergentes e inténtalo de nuevo.');
    }

    final resultado = Completer<Map<String, dynamic>?>();
    late final JSFunction listener;
    listener = ((web.MessageEvent event) {
      if (event.origin != web.window.location.origin) return;
      Map<String, dynamic> mensaje;
      try {
        mensaje = jsonDecode((event.data as JSString).toDart) as Map<String, dynamic>;
      } catch (_) {
        // No era el mensaje que esperamos (p. ej. de una extensión del
        // navegador): se ignora, no se da por terminado el login.
        return;
      }
      if (mensaje['type'] != _mensajeGoogleLogin) return;
      if (!resultado.isCompleted) resultado.complete(mensaje);
    }).toJS;
    web.window.addEventListener('message', listener);

    // Si la persona cierra la ventana a mano sin elegir cuenta, nunca llega
    // un postMessage — sin esto, `start()` se quedaría esperando para siempre.
    final vigilarCierre = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (popup.closed && !resultado.isCompleted) {
        t.cancel();
        resultado.complete(null);
      }
    });

    try {
      final mensaje = await resultado.future;
      if (mensaje == null) return null;
      final error = mensaje['error'] as String?;
      if (error != null) {
        throw AuthError((mensaje['message'] as String?) ?? 'No se pudo iniciar sesión con Google');
      }
      final token = mensaje['token'] as String?;
      if (token == null) return null;
      final user = await authService.getCurrentUser(token);
      return AuthResponse(token: token, user: user);
    } finally {
      vigilarCierre.cancel();
      web.window.removeEventListener('message', listener);
      if (!popup.closed) popup.close();
    }
  }
}
