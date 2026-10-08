import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../navegacion/rutas.dart';
import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/date_format_es.dart';
import '../../widgets/admin/admin_shell.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/admin/ds_section_card.dart';
import '../../widgets/admin/ds_stat_card.dart';
import '../../widgets/themed_builder.dart';
import 'admin_admins_page.dart';
import 'admin_ar_page.dart';
import 'admin_businesses_page.dart';
import 'admin_help_page.dart';
import 'admin_mapa_page.dart';
import 'admin_negocio_detalle_page.dart';
import 'admin_resenas_page.dart';
import 'admin_reports_page.dart';
import 'admin_requests_page.dart';
import 'admin_settings_page.dart';
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
        return _InicioContent(admin: widget.admin, authService: widget.authService, onNavigate: _ir);
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
      case AdminSection.configuracion:
        return AdminSettingsPage(admin: widget.admin);
      case AdminSection.ayuda:
        return AdminHelpPage();
    }
  }
}

class _InicioContent extends StatefulWidget {
  final AuthUser admin;
  final AuthService authService;
  final ValueChanged<AdminSection> onNavigate;

  const _InicioContent({required this.admin, required this.authService, required this.onNavigate});

  @override
  State<_InicioContent> createState() => _InicioContentState();
}

class _InicioContentState extends State<_InicioContent> {
  AdminStats? _stats;
  String? _error;
  bool _loading = true;

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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.adminViolet,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
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
                  Text('Atajos del sistema', style: AppTypography.h3),
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
    final items = [
      (Icons.groups_outlined, stats.turistas, 'Visitantes registrados', AppColors.turquesa),
      (Icons.apartment, stats.negociosActivos, 'Negocios activos', AppColors.turquesa),
      (Icons.report_gmailerrorred_outlined, stats.negociosPendientes, 'Solicitudes pendientes', AppColors.amarillo),
      (Icons.store_outlined, stats.negociosTotal, 'Negocios totales', AppColors.turquesa),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = Breakpoints.isCompact(constraints.maxWidth);
        return GridView.count(
          crossAxisCount: compact ? 2 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: compact ? 1.05 : 1.35,
          children: items.map((s) {
            final (icon, value, label, color) = s;
            // Solo las solicitudes pendientes piden atención (cuando hay).
            final alerta = icon == Icons.report_gmailerrorred_outlined && value > 0;
            return DsStatCard(icon: icon, value: value, label: label, accent: color, alerta: alerta);
          }).toList(),
        );
      },
    );
  }
}

class _SectionsGrid extends StatelessWidget {
  final ValueChanged<AdminSection> onNavigate;
  const _SectionsGrid({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.report_gmailerrorred_outlined, 'Solicitudes', AppColors.amber, AdminSection.solicitudes),
      (Icons.group_outlined, 'Usuarios', AppColors.brandTeal, AdminSection.usuarios),
      (Icons.apartment_outlined, 'Negocios', AppColors.businessOrange, AdminSection.negocios),
      (Icons.view_in_ar_outlined, 'Mapa y RA', AppColors.emerald, AdminSection.mapa),
      (Icons.shield_outlined, 'Admins', AppColors.adminViolet, AdminSection.admins),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = Breakpoints.isCompact(constraints.maxWidth);
        return GridView.count(
          crossAxisCount: compact ? 1 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: compact ? 5.5 : 4.2,
          children: items.map((s) {
            final (icon, title, color, section) = s;
            return DsSectionCard(
              icon: icon,
              title: title,
              accent: color,
              onTap: () => onNavigate(section),
            );
          }).toList(),
        );
      },
    );
  }
}
