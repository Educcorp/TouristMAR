import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navegacion/rutas.dart';
import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format_es.dart';
import '../../widgets/tablero_cifras.dart';
import '../../widgets/admin/admin_shell.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/themed_builder.dart';
import 'admin_admins_page.dart';
import 'admin_ar_page.dart';
import 'admin_businesses_page.dart';
import 'admin_mapa_page.dart';
import 'admin_negocio_detalle_page.dart';
import 'admin_resenas_page.dart';
import 'admin_reports_page.dart';
import 'admin_requests_page.dart';
import 'admin_users_page.dart';

/// Host del panel admin: aloja [AdminShell] y decide qué contenido mostrar en
/// el área central según la sección elegida en el sidebar. El sidebar/topbar
/// nunca se remonta al cambiar de sección — solo el contenido central.
class AdminDashboardPage extends StatefulWidget {
  final AuthUser admin;
  final AuthService authService;

  /// Sección visible (viene de la URL: `/admin/<seccion>`).
  final AdminSection seccion;

  /// Lugar abierto dentro de "Mapa y RA" (`/admin/mapa/lugar/<id>`).
  final String? lugarId;

  AdminDashboardPage({
    super.key,
    required this.admin,
    AuthService? authService,
    this.seccion = AdminSection.inicio,
    this.lugarId,
  }) : authService = authService ?? AuthService();

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  AdminSection get _selected => widget.seccion;

  void _ir(AdminSection seccion) => context.go(rutaAdmin(seccion));

  /// Cambia para volver a montar (y recargar) "Solicitudes" después de
  /// revisar una solicitud abierta desde una notificación.
  int _versionSolicitudes = 0;

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _buildShell);

  Widget _buildShell(BuildContext context) {
    return AdminShell(
      admin: widget.admin,
      selected: _selected,
      onSelect: _ir,
      onNotificationTap: _handleNotificationTap,
      body: _buildBody(),
    );
  }

  void _handleNotificationTap(AppNotification notification) {
    final section = adminSectionForNotification(notification.tipo);
    if (section != null) _ir(section);
    // Una solicitud de negocio (registro nuevo o negocio adicional) abre
    // directo su detalle: imagen, nombre, ubicación… para revisarla y editarla.
    final negocioId = notification.negocioId;
    final esSolicitudDeNegocio = notification.tipo == 'negocio_pendiente' || notification.tipo == 'negocio_sugerido';
    if (esSolicitudDeNegocio && negocioId != null) {
      // Después del cambio de sección, para abrirlo encima de "Solicitudes".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _abrirSolicitud(negocioId);
      });
    }
  }

  Future<void> _abrirSolicitud(String negocioId) async {
    final resultado = await abrirDetalleNegocio(context, negocioId: negocioId, authService: widget.authService);
    if (!mounted || resultado == null) return;
    if (resultado.abrirContenido != null) {
      // El contenido de RA (recorrido 360° y marcadores) se agrega en la
      // ficha del lugar dentro de "Mapa y RA".
      context.go(rutaLugarAdmin(negocioId));
      return;
    }
    setState(() => _versionSolicitudes++);
  }

  Widget _buildBody() {
    switch (_selected) {
      case AdminSection.inicio:
        return _InicioContent(
          admin: widget.admin,
          authService: widget.authService,
          onNavigate: _ir,
          onNotificationTap: _handleNotificationTap,
        );
      case AdminSection.solicitudes:
        return AdminRequestsPage(key: ValueKey(_versionSolicitudes), authService: widget.authService);
      case AdminSection.usuarios:
        return AdminUsersPage(authService: widget.authService);
      case AdminSection.negocios:
        return AdminBusinessesPage(authService: widget.authService);
      case AdminSection.resenas:
        return AdminResenasPage();
      case AdminSection.mapa:
        return AdminMapaPage(admin: widget.admin, authService: widget.authService, lugarId: widget.lugarId);
      case AdminSection.realidadAumentada:
        return AdminArPage(authService: widget.authService);
      case AdminSection.admins:
        return AdminAdminsPage(currentAdmin: widget.admin, authService: widget.authService);
      case AdminSection.reportes:
        return AdminReportsPage(authService: widget.authService);
    }
  }
}

class _InicioContent extends StatefulWidget {
  final AuthUser admin;
  final AuthService authService;
  final ValueChanged<AdminSection> onNavigate;
  final ValueChanged<AppNotification> onNotificationTap;

  const _InicioContent({
    required this.admin,
    required this.authService,
    required this.onNavigate,
    required this.onNotificationTap,
  });

  @override
  State<_InicioContent> createState() => _InicioContentState();
}

class _InicioContentState extends State<_InicioContent> {
  AdminStats? _stats;
  String? _error;
  bool _loading = true;

  /// Las más recientes, para la tarjeta de vista previa; `null` mientras cargan.
  List<AppNotification>? _notificaciones;

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
    _cargarNotificaciones(token);
    try {
      final stats = await widget.authService.adminGetStats(token);
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cargarNotificaciones(String token) async {
    try {
      final lista = await widget.authService.listNotifications(token);
      if (mounted) setState(() => _notificaciones = lista);
    } catch (_) {
      if (mounted) setState(() => _notificaciones = const []);
    }
  }

  Future<void> _abrirNotificacion(AppNotification n) async {
    final token = SessionStorage.token;
    if (!n.leida && token != null) {
      setState(() => _notificaciones = [for (final x in _notificaciones ?? const <AppNotification>[]) x.id == n.id ? x.copyWith(leida: true) : x]);
      widget.authService.markNotificationRead(token, n.id).catchError((_) {});
    }
    widget.onNotificationTap(n);
  }

  Future<void> _verTodas() async {
    final tocada = await showNotificationsDialog(context, AppColors.adminViolet);
    final token = SessionStorage.token;
    if (token != null) _cargarNotificaciones(token);
    if (tocada != null) widget.onNotificationTap(tocada);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.adminViolet,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppAncho.pagina),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Hero(),
                  const SizedBox(height: AppSpacing.lg),
                  if (_loading)
                    DsLoadingState()
                  else if (_error != null)
                    DsErrorState(message: _error!, onRetry: _load)
                  else if (_stats != null)
                    _StatsGrid(stats: _stats!),
                  const SizedBox(height: AppSpacing.xl),
                  _NotificacionesCard(
                    notificaciones: _notificaciones,
                    onTap: _abrirNotificacion,
                    onVerTodas: _verTodas,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Ir a', style: AppTypography.h2),
                  const SizedBox(height: AppSpacing.sm),
                  _SectionsGrid(onNavigate: widget.onNavigate),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vista previa de las últimas notificaciones en el inicio del admin, con
/// acceso a la lista completa (el mismo panel que abre la campana).
class _NotificacionesCard extends StatelessWidget {
  final List<AppNotification>? notificaciones;
  final ValueChanged<AppNotification> onTap;
  final VoidCallback onVerTodas;

  const _NotificacionesCard({required this.notificaciones, required this.onTap, required this.onVerTodas});

  static const _maximo = 4;

  @override
  Widget build(BuildContext context) {
    final lista = notificaciones;
    final sinLeer = lista?.where((n) => !n.leida).length ?? 0;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_outlined, size: 20, color: AppColors.tinta),
              const SizedBox(width: 8),
              Text('Notificaciones', style: AppTypography.h3),
              if (sinLeer > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.amarillo, borderRadius: BorderRadius.circular(999)),
                  child: Text('$sinLeer sin leer',
                      style: const TextStyle(color: AppColors.riel, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
              const Spacer(),
              TextButton(onPressed: onVerTodas, child: const Text('Ver todas')),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (lista == null)
            DsLoadingState()
          else if (lista.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text('Sin notificaciones por ahora.', textAlign: TextAlign.center, style: AppTypography.bodySmall),
            )
          else
            for (final n in lista.take(_maximo)) ...[
              NotificacionTile(notification: n, compacta: true, onTap: () => onTap(n)),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Panel de administración', style: AppTypography.h1),
        const SizedBox(height: 4),
        Text('Manzanillo, Colima · ${formatDateEs(DateTime.now())}', style: AppTypography.body),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final AdminStats stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return TableroCifras(celdas: [
      CeldaCifra(Icons.groups_outlined, '${stats.turistas}', 'Visitantes registrados'),
      CeldaCifra(Icons.apartment, '${stats.negociosActivos}', 'Negocios activos'),
      // Solo las solicitudes pendientes piden atención (cuando hay).
      CeldaCifra(Icons.pending_actions_outlined, '${stats.negociosPendientes}', 'Solicitudes pendientes',
          alerta: stats.negociosPendientes > 0),
      CeldaCifra(Icons.store_outlined, '${stats.negociosTotal}', 'Negocios en total'),
    ]);
  }
}

/// Accesos a las secciones que más se usan, como lista (la misma pieza que
/// "Gestionar negocio" en el panel de empresa) en vez de una cuadrícula de
/// tarjetas con ícono que repetía el menú lateral.
class _SectionsGrid extends StatelessWidget {
  final ValueChanged<AdminSection> onNavigate;
  const _SectionsGrid({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.pending_actions_outlined, 'Solicitudes', 'Aprueba o rechaza negocios nuevos', AdminSection.solicitudes),
      (Icons.apartment_outlined, 'Negocios', 'Catálogo, categorías y fichas', AdminSection.negocios),
      (Icons.map_outlined, 'Lugares y experiencias', 'Pins del mapa, RA y recorridos 360°', AdminSection.mapa),
      (Icons.group_outlined, 'Usuarios', 'Edita o bloquea cuentas', AdminSection.usuarios),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cubierta,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.borderSubtle),
            ListTile(
              onTap: () => onNavigate(items[i].$4),
              minTileHeight: 64,
              leading: Icon(items[i].$1, color: AppColors.tinta),
              title: Text(items[i].$2, style: AppTypography.h3),
              subtitle: Text(items[i].$3, style: AppTypography.bodySmall),
              trailing: Icon(Icons.chevron_right, color: AppColors.slate400),
            ),
          ],
        ],
      ),
    );
  }
}
