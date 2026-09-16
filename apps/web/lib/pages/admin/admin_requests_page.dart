import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../utils/date_format_es.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_icon_badge.dart';
import '../../widgets/admin/ds_states.dart';

/// Contenido de la sección "Solicitudes" embebido en [AdminShell] — sin
/// Scaffold/AppBar propio, ya que el sidebar/topbar los provee el shell.
class AdminRequestsPage extends StatefulWidget {
  final AuthService authService;

  AdminRequestsPage({super.key, AuthService? authService}) : authService = authService ?? AuthService();

  @override
  State<AdminRequestsPage> createState() => _AdminRequestsPageState();
}

class _AdminRequestsPageState extends State<AdminRequestsPage> {
  List<NegocioSummary> _requests = [];
  bool _loading = true;
  String? _error;
  final Set<String> _deciding = {};

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
      final requests = await widget.authService.adminListNegociosPendientes(token);
      if (!mounted) return;
      setState(() => _requests = requests);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(NegocioSummary negocio, bool approve) async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _deciding.add(negocio.id));
    try {
      if (approve) {
        await widget.authService.adminApproveNegocio(token, negocio.id);
      } else {
        await widget.authService.adminRejectNegocio(token, negocio.id);
      }
      if (!mounted) return;
      setState(() => _requests.removeWhere((r) => r.id == negocio.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Solicitud aprobada. El negocio ya puede acceder a su panel.' : 'Solicitud rechazada.')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err is AuthError ? err.message : 'No se pudo procesar la solicitud')),
      );
    } finally {
      if (mounted) setState(() => _deciding.remove(negocio.id));
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
            Row(
              children: [
                Text('Solicitudes', style: AppTypography.h1),
                if (_requests.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  DsBadge(text: '${_requests.length}', tone: BadgeTone.warning),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text('Gestiona y da seguimiento a las solicitudes del sistema.', style: AppTypography.body),
            SizedBox(height: AppSpacing.xl),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return DsLoadingState();
    if (_error != null) return DsErrorState(message: _error!, onRetry: _load);
    if (_requests.isEmpty) {
      return const DsEmptyState(
        icon: Icons.mark_email_read_outlined,
        title: 'No hay solicitudes pendientes',
        subtitle: 'Cuando recibas nuevas solicitudes, aparecerán aquí.',
      );
    }
    return Column(
      children: _requests
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _RequestRow(
                  negocio: r,
                  isDeciding: _deciding.contains(r.id),
                  onApprove: () => _decide(r, true),
                  onReject: () => _decide(r, false),
                ),
              ))
          .toList(),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final NegocioSummary negocio;
  final bool isDeciding;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestRow({required this.negocio, required this.isDeciding, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final date = formatDateEs(negocio.solicitadoEn);

    return DsCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = Breakpoints.isCompact(constraints.maxWidth);
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsIconBadgeCircle(icon: Icons.apartment, color: AppColors.businessOrange),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(negocio.nombre, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(negocio.categoria ?? 'Sin categoría', style: AppTypography.bodySmall),
                  ],
                ),
              ),
              if (negocio.esAdicional) ...[
                const DsBadge(text: 'Negocio adicional', tone: BadgeTone.info),
                const SizedBox(width: AppSpacing.sm),
              ],
              const DsBadge(text: 'Pendiente', tone: BadgeTone.warning),
            ],
          );

          final meta = Padding(
            padding: EdgeInsets.only(top: AppSpacing.md, left: compact ? 0 : 56),
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: 6,
              children: [
                _InfoChip(icon: Icons.person_outline, text: negocio.contacto),
                _InfoChip(icon: Icons.mail_outline, text: negocio.email),
                _InfoChip(icon: Icons.event_outlined, text: date),
              ],
            ),
          );

          final actions = Padding(
            padding: EdgeInsets.only(top: AppSpacing.md, left: compact ? 0 : 56),
            child: isDeciding
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate400),
                  )
                : Row(
                    children: [
                      DsButton(label: 'Rechazar', variant: DsButtonVariant.danger, size: DsButtonSize.sm, onPressed: onReject),
                      const SizedBox(width: AppSpacing.sm),
                      DsButton(
                        label: 'Aprobar',
                        variant: DsButtonVariant.secondary,
                        accent: AppColors.emerald,
                        size: DsButtonSize.sm,
                        onPressed: onApprove,
                      ),
                    ],
                  ),
          );

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [identity, meta, actions]);
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.slate500),
        const SizedBox(width: 6),
        Text(text, style: AppTypography.bodySmall),
      ],
    );
  }
}
