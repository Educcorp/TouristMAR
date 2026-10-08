// Este archivo solo se importa en la build web (import condicional en
// platform_services.dart), así que usar las APIs del navegador aquí es
// correcto. Migrado de `dart:html` (obsoleto) a `package:web`.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

import '../services/auth_service.dart';
import 'platform_types.dart';

KeyValueStore createDefaultStore() => _LocalStorageStore();

GoogleLogin createDefaultGoogleLogin() => _RedirectGoogleLogin();

class _LocalStorageStore implements KeyValueStore {
  @override
  String? read(String key) => web.window.localStorage.getItem(key);

  @override
  void write(String key, String value) => web.window.localStorage.setItem(key, value);

  @override
  void remove(String key) => web.window.localStorage.removeItem(key);
}

class _RedirectGoogleLogin implements GoogleLogin {
  @override
  GoogleRedirectResult consumeRedirectResult() {
    final uri = Uri.base;
    final token = uri.queryParameters['token'];
    final error = uri.queryParameters['error'];

    if (token != null || error != null) {
      web.window.history.replaceState(null, '', uri.path);
    }

    return GoogleRedirectResult(token: token, error: error, message: uri.queryParameters['message']);
  }

  @override
  Future<AuthResponse?> start(AuthService authService) async {
    web.window.location.href = authService.googleLoginUrl;
    return null;
  }
}
