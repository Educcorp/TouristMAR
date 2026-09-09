import 'dart:html' as html;

const _tokenKey = 'touristmar_token';

class SessionStorage {
  static String? get token => html.window.localStorage[_tokenKey];

  static void saveToken(String token) {
    html.window.localStorage[_tokenKey] = token;
  }

  static void clearToken() {
    html.window.localStorage.remove(_tokenKey);
  }
}
