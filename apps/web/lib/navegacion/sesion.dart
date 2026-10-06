import 'package:flutter/foundation.dart';

import '../models/business_profile.dart';
import '../models/visitor_profile.dart';
import '../platform/platform_services.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';

/// Quién tiene la sesión abierta, en un solo lugar. El enrutador
/// (`rutas.dart`) lo escucha: al iniciar o cerrar sesión, o si el servidor
/// bloquea la cuenta, la app se va sola a la pantalla que corresponde.
///
/// Antes cada pantalla recibía el usuario por constructor y la sesión se
/// restauraba dentro del formulario de login; ahora se restaura una vez al
/// abrir la app ([restaurar]), así cualquier ruta funciona al recargar.
class Sesion {
  Sesion._();

  static final usuario = ValueNotifier<AuthUser?>(null);

  /// Mensaje para mostrar en el login la próxima vez que se abra (sesión
  /// expirada, cuenta bloqueada, error al entrar con Google).
  static String? mensajePendiente;

  static VisitorProfile? _perfil;
  static List<BusinessProfile>? _negocios;

  /// Abre la sesión guardada (o la que regresa del login con Google en la
  /// web). Si el token ya no sirve, la borra.
  static Future<void> restaurar([AuthService? authService]) async {
    final redirect = PlatformServices.googleLogin.consumeRedirectResult();
    if (redirect.error != null) {
      mensajePendiente = redirect.message ?? 'No se pudo iniciar sesión con Google';
    }
    final token = redirect.token ?? SessionStorage.token;
    if (token == null) return;
    try {
      final user = await (authService ?? AuthService()).getCurrentUser(token);
      SessionStorage.saveToken(token);
      iniciar(user);
    } catch (_) {
      SessionStorage.clearToken();
    }
  }

  static void iniciar(AuthUser user) {
    _perfil = null;
    _negocios = null;
    usuario.value = user;
  }

  static void cerrar({String? mensaje}) {
    SessionStorage.clearToken();
    mensajePendiente = mensaje;
    _perfil = null;
    _negocios = null;
    usuario.value = null;
  }

  /// Toma (y borra) el mensaje pendiente para el login.
  static String? tomarMensaje() {
    final m = mensajePendiente;
    mensajePendiente = null;
    return m;
  }

  /// Perfil del visitante: una sola instancia para todas sus pantallas, así
  /// lo que se edita en "Mi perfil" se ve igual en el inicio y en el mapa.
  static VisitorProfile get perfilVisitante => _perfil ??= VisitorProfile.fromAuthUser(usuario.value!);

  /// Negocios de la cuenta de empresa (misma idea que [perfilVisitante]).
  static List<BusinessProfile> get negocios => _negocios ??=
      usuario.value!.negocios.map((n) => BusinessProfile.fromNegocioInfo(usuario.value!, n)).toList();

  static BusinessProfile? negocio(String? id) {
    for (final n in negocios) {
      if (n.id == id) return n;
    }
    return null;
  }
}

/// Pantalla de inicio de cada rol. null = no tiene panel todavía (negocio en
/// revisión o rechazado): se queda en el login viendo su estado.
String? rutaInicio(AuthUser user) {
  if (user.isAdmin) return '/admin/inicio';
  if (user.isNegocio) return user.negociosAprobados.isNotEmpty ? '/empresa/inicio' : null;
  return '/inicio';
}

@visibleForTesting
void reiniciarSesionParaPruebas() {
  Sesion.mensajePendiente = null;
  Sesion._perfil = null;
  Sesion._negocios = null;
  Sesion.usuario.value = null;
}
