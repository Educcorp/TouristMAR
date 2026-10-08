import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../utils/date_format_es.dart';
import '../utils/keyboard.dart';
import 'admin/ds_states.dart';

/// Campana de notificaciones compartida por los 3 paneles (visitante,
/// empresa, admin). Revisa el contador de no leídas cada 30s (mismo
/// intervalo que [SessionGuard], pero en un timer propio: este widget no
/// siempre vive dentro de uno) y abre un diálogo con el detalle al tocarla.
class NotificationBell extends StatefulWidget {
  final Color accentColor;
  final ValueChanged<AppNotification>? onNotificationTap;

  const NotificationBell({super.key, required this.accentColor, this.onNotificationTap});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _authService = AuthService();
  Timer? _timer;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refreshCount();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshCount());
  }

  Future<void> _refreshCount() async {
    final token = SessionStorage.token;
    if (token == null) return;
    try {
      final count = await _authService.unreadNotificationCount(token);
      if (mounted) setState(() => _unread = count);
    } catch (_) {
      // Error pasajero: se reintenta en el siguiente tick.
    }
  }

  Future<void> _openPanel() async {
    final tapped = await showNotificationsDialog(context, widget.accentColor);
    _refreshCount();
    if (tapped != null) widget.onNotificationTap?.call(tapped);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: _openPanel,
        customBorder: const CircleBorder(),
        hoverColor: widget.accentColor.withValues(alpha: 0.12),
        splashColor: widget.accentColor.withValues(alpha: 0.18),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_none, color: AppColors.slate300),
              if (_unread > 0)
                Positioned(
                  right: -4,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(color: widget.accentColor, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      _unread > 9 ? '9+' : '$_unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre el mismo panel de notificaciones que la campana — usado también
/// desde el ítem "Notificaciones" del drawer, para que ambos accesos lleven
/// al mismo lugar en vez de duplicar la lógica. Si se toca una notificación
/// (no los botones "Cerrar"/"Marcar todas"), el diálogo se cierra solo y
/// devuelve esa notificación para que el llamador decida a dónde navegar.
Future<AppNotification?> showNotificationsDialog(BuildContext context, Color accentColor) {
  // Sin esto, si la barra de búsqueda tenía el foco, al cerrar el diálogo
  // Flutter se lo regresa y el teclado se abre solo (Error 2).
  hideKeyboard();
  return showDialog<AppNotification?>(
    context: context,
    builder: (_) => _NotificationsDialog(accentColor: accentColor),
  );
}

class _NotificationsDialog extends StatefulWidget {
  final Color accentColor;

  const _NotificationsDialog({required this.accentColor});

  @override
  State<_NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<_NotificationsDialog> {
  final _authService = AuthService();
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifications = await _authService.listNotifications(token);
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(AppNotification n) async {
    if (n.leida) return;
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      final idx = _notifications.indexWhere((x) => x.id == n.id);
      if (idx != -1) _notifications[idx] = n.copyWith(leida: true);
    });
    try {
      await _authService.markNotificationRead(token, n.id);
    } catch (_) {
      // Si falla, se queda marcada como leída solo visualmente hasta el
      // próximo refresh — no vale la pena bloquear al usuario por esto.
    }
  }

  Future<void> _markAllRead() async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _notifications = _notifications.map((n) => n.copyWith(leida: true)).toList());
    try {
      await _authService.markAllNotificationsRead(token);
    } catch (_) {}
  }

  /// Tocar una notificación (a diferencia de "Marcar todas"/"Cerrar") cierra
  /// el panel y le entrega la notificación a quien lo abrió, para que
  /// navegue a su contenido relacionado.
  Future<void> _handleTileTap(AppNotification n) async {
    await _markRead(n);
    if (mounted) Navigator.of(context).pop(n.copyWith(leida: true));
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.leida);

    return AlertDialog(
      backgroundColor: AppColors.panelNavySoft,
      title: Row(
        children: [
          Expanded(child: Text('Notificaciones', style: TextStyle(color: AppColors.textPrimary))),
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Marcar todas como leídas', style: TextStyle(color: widget.accentColor, fontSize: 12)),
            ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cerrar', style: TextStyle(color: AppColors.slate400)),
        ),
      ],
    );
  }

  // Antes era un SizedBox de altura fija (120): le quedaba justo a
  // DsLoadingState/DsErrorState, pero DsEmptyState (icono + título + texto)
  // necesita más y se salía por abajo. Con un mínimo en vez de una altura
  // fija, el contenido puede crecer si lo necesita.
  Widget _buildContent() {
    if (_loading) {
      return ConstrainedBox(constraints: const BoxConstraints(minHeight: 120), child: DsLoadingState());
    }
    if (_error != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 120),
        child: DsErrorState(message: _error!, onRetry: _load),
      );
    }
    if (_notifications.isEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 120),
        child: const DsEmptyState(
          icon: Icons.notifications_none,
          title: 'Sin notificaciones',
          subtitle: 'Cuando haya novedades, aparecerán aquí.',
        ),
      );
    }

    // 420 es cómodo en escritorio, pero en un celular la pantalla completa
    // suele medir menos que eso: el diálogo se salía por abajo unos pixeles.
    // Se limita también a un porcentaje de la altura disponible.
    final maxHeight = math.min(420.0, MediaQuery.sizeOf(context).height * 0.55);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => Divider(color: AppColors.overlay(0.08), height: 16),
        itemBuilder: (context, i) => _NotificationTile(
          notification: _notifications[i],
          accentColor: widget.accentColor,
          onTap: () => _handleTileTap(_notifications[i]),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final Color accentColor;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.accentColor, required this.onTap});

  IconData get _icon {
    switch (notification.tipo) {
      case 'negocio_aprobado':
        return Icons.check_circle_outline;
      case 'negocio_rechazado':
        return Icons.cancel_outlined;
      case 'negocio_sugerido':
        return Icons.add_business_outlined;
      case 'usuario_nuevo':
        return Icons.person_add_alt_outlined;
      case 'recorrido_solicitado':
        return Icons.threesixty;
      case 'recorrido_listo':
        return Icons.check_circle_outline;
      case 'recorrido_rechazado':
        return Icons.cancel_outlined;
      default:
        return Icons.apartment_outlined;
    }
  }

  Color get _color {
    switch (notification.tipo) {
      case 'negocio_aprobado':
      case 'recorrido_listo':
        return AppColors.brandTeal;
      case 'negocio_rechazado':
      case 'recorrido_rechazado':
        return AppColors.errorRed;
      default:
        return accentColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: notification.leida ? Colors.transparent : accentColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(_icon, size: 16, color: _color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.titulo,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: notification.leida ? FontWeight.w500 : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!notification.leida) ...[
                          const SizedBox(width: 6),
                          Container(width: 7, height: 7, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(notification.cuerpo, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.35)),
                    const SizedBox(height: 4),
                    Text(formatDateEs(notification.createdAt), style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
