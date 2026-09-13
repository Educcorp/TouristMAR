import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';

class AdminBusinessesPage extends StatefulWidget {
  final AuthService authService;

  AdminBusinessesPage({super.key, AuthService? authService}) : authService = authService ?? AuthService();

  @override
  State<AdminBusinessesPage> createState() => _AdminBusinessesPageState();
}

class _AdminBusinessesPageState extends State<AdminBusinessesPage> {
  List<NegocioSummary> _negocios = [];
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
      final negocios = await widget.authService.adminListNegocios(token);
      if (!mounted) return;
      setState(() => _negocios = negocios);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
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
            const Text('Gestión de negocios'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.businessOrange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.businessOrange.withOpacity(0.3)),
              ),
              child: Text('${_negocios.length}', style: const TextStyle(color: AppColors.businessOrange, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
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
      return const Center(child: CircularProgressIndicator(color: AppColors.businessOrange));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.errorRed)));
    }
    if (_negocios.isEmpty) {
      return const Center(child: Text('Todavía no hay negocios registrados.', style: TextStyle(color: AppColors.slate400)));
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _negocios.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _BusinessTile(negocio: _negocios[i]),
    );
  }
}

class _BusinessTile extends StatelessWidget {
  final NegocioSummary negocio;

  const _BusinessTile({required this.negocio});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (negocio.estado) {
      'aprobado' => ('Activo', Colors.greenAccent),
      'rechazado' => ('Rechazado', AppColors.errorRed),
      _ => ('Pendiente', Colors.amber),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.businessOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.businessOrange.withOpacity(0.2)),
            ),
            child: const Icon(Icons.apartment, size: 18, color: AppColors.businessOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(negocio.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(negocio.categoria ?? 'Sin categoría', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
