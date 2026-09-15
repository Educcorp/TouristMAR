import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/login_page.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';

/// Envuelve la pantalla principal de cualquier rol (visitante/empresa/admin)
/// y revisa periódicamente con el backend que la cuenta siga activa. Un
/// token firmado sigue siendo válido aunque un admin bloquee la cuenta a
/// mitad de sesión — sin esto, quien ya inició sesión podía seguir navegando
/// hasta recargar. En cuanto el backend responde que la cuenta está
/// bloqueada, cierra la sesión y manda de vuelta al login con un aviso.
class SessionGuard extends StatefulWidget {
  final Widget child;

  const SessionGuard({super.key, required this.child});

  static const _interval = Duration(seconds: 30);

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  final _authService = AuthService();
  Timer? _timer;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(SessionGuard._interval, (_) => _check());
  }

  Future<void> _check() async {
    if (_handled) return;
    final token = SessionStorage.token;
    if (token == null) return;

    try {
      final user = await _authService.getCurrentUser(token);
      if (!user.activo) _endSession(_blockedMessage);
    } on AuthError catch (err) {
      // Token inválido/expirado o cuenta bloqueada — cualquiera de los dos
      // significa que esta sesión ya no es válida en el servidor.
      _endSession(err.isBlocked ? _blockedMessage : 'Tu sesión expiró, inicia sesión de nuevo.');
    } catch (_) {
      // Error de red pasajero: no cerrar sesión por eso, se reintenta en el
      // siguiente tick.
    }
  }

  static const _blockedMessage =
      'Tu cuenta ha sido bloqueada por un administrador. Contacta a soporte si crees que es un error.';

  void _endSession(String message) {
    if (_handled || !mounted) return;
    _handled = true;
    _timer?.cancel();
    SessionStorage.clearToken();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginPage(initialError: message)),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
