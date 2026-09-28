import '../platform/platform_services.dart';

const _tokenKey = 'touristmar_token';

class SessionStorage {
  static String? get token => PlatformServices.store.read(_tokenKey);

  static void saveToken(String token) {
    PlatformServices.store.write(_tokenKey, token);
  }

  static void clearToken() {
    PlatformServices.store.remove(_tokenKey);
  }
}
