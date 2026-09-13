import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/app_shell.dart';
import 'admin_admins_page.dart';
import 'admin_businesses_page.dart';
import 'admin_requests_page.dart';
import 'admin_users_page.dart';

class AdminDashboardPage extends StatefulWidget {
  final AuthUser admin;
  final AuthService authService;

  AdminDashboardPage({super.key, required this.admin, AuthService? authService})
      : authService = authService ?? AuthService();

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
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
    return AppShell(
      accentColor: AppColors.adminViolet,
      badgeText: 'ADMIN',
      avatarIcon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.adminViolet.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.adminViolet.withOpacity(0.4)),
        ),
        child: const Icon(Icons.shield_outlined, size: 16, color: AppColors.adminViolet),
      ),
      drawerIdentity: AdminIdentityCard(admin: widget.admin),
      navItems: adminNavItems(context, admin: widget.admin),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(),
                    const SizedBox(height: 20),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator(color: AppColors.adminViolet)),
                      )
                    else if (_error != null)
                      _buildErrorBanner()
                    else if (_stats != null)
                      _buildStatsGrid(_stats!),
                    const SizedBox(height: 28),
                    const Text(
                      'Secciones del sistema',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickNav(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      height: 130,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E1065), Color(0xFF081824)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: const [
              Icon(Icons.shield_outlined, size: 14, color: AppColors.adminViolet),
              SizedBox(width: 6),
              Text('PANEL DE ADMINISTRACIÓN',
                  style: TextStyle(color: AppColors.adminViolet, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 6),
          Text('TourisMAR — Admin', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
          const SizedBox(height: 2),
          const Text('Gestión central del sistema turístico', style: TextStyle(color: AppColors.slate300, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.errorRed.withOpacity(0.25)),
      ),
      child: Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
    );
  }

  Widget _buildStatsGrid(AdminStats stats) {
    final items = [
      (Icons.groups_outlined, '${stats.turistas}', 'Visitantes registrados', AppColors.brandTeal),
      (Icons.apartment, '${stats.negociosActivos}', 'Negocios activos', AppColors.businessOrange),
      (Icons.report_gmailerrorred_outlined, '${stats.negociosPendientes}', 'Solicitudes pendientes', Colors.amber),
      (Icons.store_outlined, '${stats.negociosTotal}', 'Negocios totales', Colors.greenAccent),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = Breakpoints.isCompact(constraints.maxWidth) ? 2 : 4;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: items.map((s) {
            final (icon, value, label, color) = s;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(height: 8),
                  Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildQuickNav() {
    final items = [
      (Icons.report_gmailerrorred_outlined, 'Solicitudes', Colors.amber, () => _push(AdminRequestsPage())),
      (Icons.group_outlined, 'Usuarios', AppColors.brandTeal, () => _push(AdminUsersPage())),
      (Icons.apartment, 'Negocios', AppColors.businessOrange, () => _push(AdminBusinessesPage())),
      (Icons.shield_outlined, 'Admins', AppColors.adminViolet, () => _push(AdminAdminsPage(currentAdmin: widget.admin))),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = Breakpoints.isCompact(constraints.maxWidth) ? 2 : 4;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: items.map((a) {
            final (icon, label, color, onTap) = a;
            return Material(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(height: 10),
                      Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
