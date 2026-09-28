import 'dart:html' as html;

import '../services/auth_service.dart';
import 'platform_types.dart';

KeyValueStore createDefaultStore() => _LocalStorageStore();

GoogleLogin createDefaultGoogleLogin() => _RedirectGoogleLogin();

class _LocalStorageStore implements KeyValueStore {
  @override
  String? read(String key) => html.window.localStorage[key];

  @override
  void write(String key, String value) => html.window.localStorage[key] = value;

  @override
  void remove(String key) => html.window.localStorage.remove(key);
}

class _RedirectGoogleLogin implements GoogleLogin {
  @override
  GoogleRedirectResult consumeRedirectResult() {
    final uri = Uri.base;
    final token = uri.queryParameters['token'];
    final error = uri.queryParameters['error'];

    if (token != null || error != null) {
      html.window.history.replaceState(null, '', uri.path);
    }

    return GoogleRedirectResult(token: token, error: error, message: uri.queryParameters['message']);
  }

  @override
  Future<AuthResponse?> start(AuthService authService) async {
    html.window.location.href = authService.googleLoginUrl;
    return null;
  }
}
