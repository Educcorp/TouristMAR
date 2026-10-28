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
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => NotificacionTile(
          notification: _notifications[i],
          onTap: () => _handleTileTap(_notifications[i]),
        ),
      ),
    );
  }
}

/// Color, icono y etiqueta de cada tipo de notificación, para distinguirlas
/// de un vistazo. Lo comparten la campana y la tarjeta del inicio del admin.
class EstiloNotificacion {
  final IconData icon;
  final Color color;
  final String etiqueta;

  const EstiloNotificacion._(this.icon, this.color, this.etiqueta);

  static const _violeta = Color(0xFF8E6BD6);

  static EstiloNotificacion of(String tipo) => switch (tipo) {
        'negocio_pendiente' => EstiloNotificacion._(Icons.hourglass_top_rounded, AppColors.amarilloTexto, 'Solicitud pendiente'),
        'negocio_sugerido' => EstiloNotificacion._(Icons.add_business_outlined, AppColors.azulTexto, 'Lugar sugerido'),
        'negocio_aprobado' => EstiloNotificacion._(Icons.check_circle_rounded, AppColors.emerald, 'Aprobado'),
        'negocio_rechazado' => EstiloNotificacion._(Icons.cancel_rounded, AppColors.rojoTexto, 'Rechazado'),
        'usuario_nuevo' => EstiloNotificacion._(Icons.person_add_alt_1_rounded, AppColors.turquesaTexto, 'Usuario nuevo'),
        'recorrido_solicitado' => const EstiloNotificacion._(Icons.threesixty_rounded, _violeta, 'Recorrido 360° solicitado'),
        'recorrido_listo' => EstiloNotificacion._(Icons.threesixty_rounded, AppColors.emerald, 'Recorrido 360° listo'),
        'recorrido_rechazado' => EstiloNotificacion._(Icons.threesixty_rounded, AppColors.rojoTexto, 'Recorrido 360° rechazado'),
        'resena_respondida' => EstiloNotificacion._(Icons.mark_chat_read_outlined, AppColors.azulTexto, 'Respuesta a tu reseña'),
        _ => EstiloNotificacion._(Icons.notifications_outlined, AppColors.slate400, 'Aviso'),
      };
}

/// Una notificación: franja e icono del color de su tipo, etiqueta del tipo,
/// título, cuerpo y fecha. Las no leídas llevan fondo tintado y punto.
class NotificacionTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  /// Una sola línea de cuerpo (vista previa del inicio del admin).
  final bool compacta;

  const NotificacionTile({super.key, required this.notification, required this.onTap, this.compacta = false});

  @override
  Widget build(BuildContext context) {
    final estilo = EstiloNotificacion.of(notification.tipo);
    final color = estilo.color;
    return Material(
      color: notification.leida ? AppColors.overlay(0.02) : color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: notification.leida ? color.withValues(alpha: 0.35) : color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(estilo.icon, size: 20, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    estilo.etiqueta.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(formatDateEs(notification.createdAt), style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                                if (!notification.leida) ...[
                                  const Spacer(),
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              notification.titulo,
                              maxLines: compacta ? 1 : null,
                              overflow: compacta ? TextOverflow.ellipsis : null,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13.5,
                                fontWeight: notification.leida ? FontWeight.w500 : FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              notification.cuerpo,
                              maxLines: compacta ? 1 : null,
                              overflow: compacta ? TextOverflow.ellipsis : null,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
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
