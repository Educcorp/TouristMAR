import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

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
    return Scaffold(
      backgroundColor: AppColors.panelNavy,
      appBar: AppBar(
        backgroundColor: AppColors.panelNavy,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Solicitudes de negocio'),
            if (_requests.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Text('${_requests.length}', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brandTeal));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.errorRed)));
    }
    if (_requests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 40),
          SizedBox(height: 12),
          Center(child: Text('Sin solicitudes pendientes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          SizedBox(height: 4),
          Center(child: Text('Todas han sido procesadas.', style: TextStyle(color: AppColors.slate400))),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = _requests[i];
        return _RequestCard(
          negocio: r,
          isDeciding: _deciding.contains(r.id),
          onApprove: () => _decide(r, true),
          onReject: () => _decide(r, false),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final NegocioSummary negocio;
  final bool isDeciding;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({required this.negocio, required this.isDeciding, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.businessOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.businessOrange.withOpacity(0.2)),
                ),
                child: const Icon(Icons.apartment, color: AppColors.businessOrange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(negocio.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(negocio.categoria ?? 'Sin categoría', style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withOpacity(0.25)),
                ),
                child: const Text('Pendiente', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.person_outline, text: negocio.contacto),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.mail_outline, text: negocio.email),
          const SizedBox(height: 14),
          if (isDeciding)
            const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate400)))
          else
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    variant: AppButtonVariant.ghost,
                    backgroundColor: AppColors.errorRed.withOpacity(0.08),
                    foregroundColor: AppColors.errorRed,
                    onPressed: onReject,
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    backgroundColor: Colors.greenAccent.withOpacity(0.15),
                    foregroundColor: Colors.greenAccent,
                    onPressed: onApprove,
                    child: const Text('Aprobar'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.slate500),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.slate300, fontSize: 12))),
      ],
    );
  }
}
