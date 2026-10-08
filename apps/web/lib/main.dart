import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'navegacion/rutas.dart';
import 'navegacion/sesion.dart';
import 'platform/platform_services.dart';
import 'services/auth_service.dart';
import 'services/experiencias_launcher.dart';
import 'services/ubicacion_dispositivo.dart';
import 'services/visor_flutter_launcher.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() {
  // URLs sin "#": el backend en producción ya regresa index.html para
  // cualquier ruta (ver apps/backend/src/index.ts), así que recargar
  // /admin/mapa funciona.
  usePathUrlStrategy();
  // Si esta pestaña es la ventana emergente del login con Google (ver
  // platform_defaults_web.dart) que ya volvió con el resultado, le avisa a
  // quien la abrió y se cierra: no debe construir la app en esta ventana.
  if (PlatformServices.googleLogin.resolvePopupIfNeeded()) return;
  // En la web el recorrido 360° se ve con el visor de Flutter (la RA solo
  // existe en la app móvil, con Unity).
  ExperienciasLauncher.current = const VisorFlutterLauncher();
  // Ubicación del navegador: ruta en el mapa y zona de RA por ubicación.
  UbicacionProvider.current = const UbicacionDispositivo();
  runApp(const TouristMarApp());
}

/// Raíz de la app (web y móvil). Primero restaura la sesión guardada y
/// después arma el enrutador, así la primera pantalla ya es la correcta (el
/// panel del rol, o la ruta que se recargó) sin pasar por el login.
class TouristMarApp extends StatefulWidget {
  /// Solo para pruebas: servicio con un cliente HTTP falso y ruta inicial.
  final AuthService? authService;
  final String? rutaInicial;

  const TouristMarApp({super.key, this.authService, this.rutaInicial});

  @override
  State<TouristMarApp> createState() => _TouristMarAppState();
}

class _TouristMarAppState extends State<TouristMarApp> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    Sesion.restaurar(widget.authService).whenComplete(() {
      if (mounted) {
        setState(() => _router = crearRouter(authService: widget.authService, inicial: widget.rutaInicial));
      }
    });
  }

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sin `key: ValueKey(mode)`: cada pantalla se reconstruye a sí misma con
    // `ThemedBuilder` (ver ese archivo) en vez de forzar la reconstrucción de
    // toda la app — así la ruta y la sesión actual sobreviven al cambio de tema.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        final router = _router;
        if (router == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.current,
            home: Scaffold(
              backgroundColor: AppColors.panelNavy,
              body: Center(child: CircularProgressIndicator(color: AppColors.brandTeal)),
            ),
          );
        }
        return MaterialApp.router(
          title: 'TouristMAR',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.current,
          routerConfig: router,
        );
      },
    );
  }
}
