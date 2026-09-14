import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/date_format_es.dart';
import '../../widgets/admin/admin_shell.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/admin/ds_section_card.dart';
import '../../widgets/admin/ds_stat_card.dart';
import 'admin_admins_page.dart';
import 'admin_businesses_page.dart';
import 'admin_help_page.dart';
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

  AdminDashboardPage({super.key, required this.admin, AuthService? authService})
      : authService = authService ?? AuthService();

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  AdminSection _selected = AdminSection.inicio;

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      admin: widget.admin,
      selected: _selected,
      onSelect: (s) => setState(() => _selected = s),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_selected) {
      case AdminSection.inicio:
        return _InicioContent(admin: widget.admin, authService: widget.authService, onNavigate: (s) => setState(() => _selected = s));
      case AdminSection.solicitudes:
        return AdminRequestsPage(authService: widget.authService);
      case AdminSection.usuarios:
        return AdminUsersPage(authService: widget.authService);
      case AdminSection.negocios:
        return AdminBusinessesPage(authService: widget.authService);
      case AdminSection.admins:
        return AdminAdminsPage(currentAdmin: widget.admin, authService: widget.authService);
      case AdminSection.reportes:
        return AdminReportsPage(authService: widget.authService);
      case AdminSection.configuracion:
        return AdminSettingsPage(admin: widget.admin);
      case AdminSection.ayuda:
        return const AdminHelpPage();
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Hero(),
            const SizedBox(height: AppSpacing.xl),
            if (_loading)
              const DsLoadingState()
            else if (_error != null)
              DsErrorState(message: _error!, onRetry: _load)
            else if (_stats != null)
              _StatsGrid(stats: _stats!),
            const SizedBox(height: AppSpacing.xxl),
            Text('Secciones del sistema', style: AppTypography.h2),
            const SizedBox(height: 2),
            Text('Accede rápidamente a los módulos principales', style: AppTypography.body),
            const SizedBox(height: AppSpacing.lg),
            _SectionsGrid(onNavigate: widget.onNavigate),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SizedBox(
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.hero),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset('assets/images/hero-manzanillo.jpg', fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.bgDeep.withOpacity(0.92),
                      AppColors.bgDeep.withOpacity(0.55),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.bgDeep.withOpacity(0.3), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = Breakpoints.isCompact(constraints.maxWidth);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 18, height: 1, color: AppColors.adminViolet),
                            const SizedBox(width: AppSpacing.sm),
                            Text('PANEL DE ADMINISTRACIÓN',
                                style: AppTypography.caption.copyWith(color: AppColors.adminViolet, letterSpacing: 2)),
                            const SizedBox(width: AppSpacing.sm),
                            Container(width: 18, height: 1, color: AppColors.adminViolet),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('TourisMAR — Admin', style: compact ? AppTypography.h1 : AppTypography.display.copyWith(fontSize: 34)),
                        const SizedBox(height: 4),
                        Text('Gestión central del sistema turístico', style: AppTypography.body.copyWith(fontSize: 15)),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.lg,
                          runSpacing: 4,
                          children: [
                            _MetaChip(icon: Icons.location_on_outlined, text: 'Manzanillo, Colima'),
                            _MetaChip(icon: Icons.calendar_today_outlined, text: formatDateEs(now)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.lg,
              right: AppSpacing.xl,
              child: Text(
                'Descubre\nManzanillo',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: AppTypography.h1.fontFamily,
                  fontStyle: FontStyle.italic,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withOpacity(0.8)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w500)),
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
      (Icons.groups_outlined, stats.turistas, 'Visitantes registrados', AppColors.brandTeal),
      (Icons.apartment, stats.negociosActivos, 'Negocios activos', AppColors.businessOrange),
      (Icons.report_gmailerrorred_outlined, stats.negociosPendientes, 'Solicitudes pendientes', AppColors.amber),
      (Icons.store_outlined, stats.negociosTotal, 'Negocios totales', AppColors.emerald),
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
          childAspectRatio: compact ? 1.05 : 1.5,
          children: items.map((s) {
            final (icon, value, label, color) = s;
            return DsStatCard(icon: icon, value: value, label: label, accent: color);
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
      (Icons.report_gmailerrorred_outlined, 'Solicitudes', 'Gestiona y da seguimiento a las solicitudes del sistema.', AppColors.amber, AdminSection.solicitudes),
      (Icons.group_outlined, 'Usuarios', 'Administra los usuarios del sistema.', AppColors.brandTeal, AdminSection.usuarios),
      (Icons.apartment_outlined, 'Negocios', 'Registra y administra los negocios turísticos.', AppColors.businessOrange, AdminSection.negocios),
      (Icons.shield_outlined, 'Admins', 'Configuración y control de administradores.', AppColors.adminViolet, AdminSection.admins),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = Breakpoints.isCompact(constraints.maxWidth) ? 2 : 4;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.95,
          children: items.map((s) {
            final (icon, title, desc, color, section) = s;
            return DsSectionCard(icon: icon, title: title, description: desc, accent: color, onTap: () => onNavigate(section));
          }).toList(),
        );
      },
    );
  }
}
