import 'platform_defaults_stub.dart' if (dart.library.html) 'platform_defaults_web.dart';
import 'platform_types.dart';

export 'platform_types.dart';

/// Punto único para lo que cambia entre navegador y teléfono. En la web ya
/// vienen listos por defecto (localStorage y redirección de Google); la app
/// móvil los reemplaza en su `main()` antes de `runApp`.
class PlatformServices {
  PlatformServices._();

  static KeyValueStore store = createDefaultStore();
  static GoogleLogin googleLogin = createDefaultGoogleLogin();
}
