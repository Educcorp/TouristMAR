import '../services/auth_service.dart';
import 'platform_types.dart';

/// Implementación por defecto fuera del navegador. Cada app (móvil) la
/// reemplaza en su `main()` con su versión real.
KeyValueStore createDefaultStore() => _MemoryStore();

GoogleLogin createDefaultGoogleLogin() => _UnconfiguredGoogleLogin();

class _MemoryStore implements KeyValueStore {
  final _values = <String, String>{};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) => _values[key] = value;

  @override
  void remove(String key) => _values.remove(key);
}

class _UnconfiguredGoogleLogin implements GoogleLogin {
  @override
  bool resolvePopupIfNeeded() => false;

  @override
  Future<AuthResponse?> start(AuthService authService) {
    throw UnsupportedError('Falta asignar PlatformServices.googleLogin en el main() de esta app.');
  }
}
