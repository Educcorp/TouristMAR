import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_icon_badge.dart';
import '../../widgets/admin/ds_states.dart';

const _estadoFiltros = ['Todos', 'aprobado', 'pendiente', 'rechazado'];
const _estadoLabels = {'aprobado': 'Activo', 'pendiente': 'Pendiente', 'rechazado': 'Rechazado'};

/// Contenido de la sección "Negocios" embebido en [AdminShell].
class AdminBusinessesPage extends StatefulWidget {
  final AuthService authService;

  AdminBusinessesPage({super.key, AuthService? authService}) : authService = authService ?? AuthService();

  @override
  State<AdminBusinessesPage> createState() => _AdminBusinessesPageState();
}

class _AdminBusinessesPageState extends State<AdminBusinessesPage> {
  final _searchController = TextEditingController();
  List<NegocioSummary> _negocios = [];
  bool _loading = true;
  String? _error;
  String _estadoFiltro = 'Todos';
  String? _categoriaFiltro;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<String> get _categorias =>
      _negocios.map((n) => n.categoria).whereType<String>().toSet().toList()..sort();

  List<NegocioSummary> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _negocios.where((n) {
      if (_estadoFiltro != 'Todos' && n.estado != _estadoFiltro) return false;
      if (_categoriaFiltro != null && n.categoria != _categoriaFiltro) return false;
      if (query.isNotEmpty && !n.nombre.toLowerCase().contains(query)) return false;
      return true;
    }).toList();
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
                Text('Negocios', style: AppTypography.h1),
                const SizedBox(width: AppSpacing.sm),
                DsBadge(text: '${_negocios.length}', tone: BadgeTone.warning),
              ],
            ),
            const SizedBox(height: 4),
            Text('Registra y administra los negocios turísticos.', style: AppTypography.body),
            const SizedBox(height: AppSpacing.lg),
            _buildFilters(),
            const SizedBox(height: AppSpacing.xl),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar negocio…',
              hintStyle: AppTypography.bodySmall,
              prefixIcon: Icon(Icons.search, size: 18, color: AppColors.slate500),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.buttonLg),
                borderSide: BorderSide(color: AppColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.buttonLg),
                borderSide: BorderSide(color: AppColors.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.buttonLg),
                borderSide: BorderSide(color: AppColors.adminViolet),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final e in _estadoFiltros)
              _FilterChip(
                label: e == 'Todos' ? 'Todos' : (_estadoLabels[e] ?? e),
                selected: _estadoFiltro == e,
                onTap: () => setState(() => _estadoFiltro = e),
              ),
            if (_categorias.isNotEmpty) ...[
              SizedBox(width: AppSpacing.sm, height: 1),
              for (final c in _categorias)
                _FilterChip(
                  label: c,
                  selected: _categoriaFiltro == c,
                  onTap: () => setState(() => _categoriaFiltro = _categoriaFiltro == c ? null : c),
                ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading) return DsLoadingState();
    if (_error != null) return DsErrorState(message: _error!, onRetry: _load);
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return const DsEmptyState(
        icon: Icons.storefront_outlined,
        title: 'Sin negocios que coincidan',
        subtitle: 'Ajusta los filtros o espera nuevos registros.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 2 : 1;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: filtered.map((n) {
            final width = columns == 1 ? constraints.maxWidth : (constraints.maxWidth - AppSpacing.md) / 2;
            return SizedBox(width: width, child: _BusinessCard(negocio: n));
          }).toList(),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.adminViolet.withOpacity(0.16) : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.adminViolet.withOpacity(0.4) : AppColors.borderSubtle),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.adminViolet : AppColors.slate300,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final NegocioSummary negocio;

  const _BusinessCard({required this.negocio});

  @override
  Widget build(BuildContext context) {
    final tone = switch (negocio.estado) {
      'aprobado' => BadgeTone.success,
      'rechazado' => BadgeTone.danger,
      _ => BadgeTone.warning,
    };
    final label = _estadoLabels[negocio.estado] ?? 'Pendiente';

    return DsCard(
      child: Row(
        children: [
          DsIconBadgeCircle(icon: Icons.apartment, color: AppColors.businessOrange, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(negocio.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(negocio.categoria ?? 'Sin categoría', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AssetDot(label: '360', active: negocio.archivo360 != null),
              const SizedBox(width: 4),
              _AssetDot(label: 'M', active: negocio.arMarcador != null),
              const SizedBox(width: 4),
              _AssetDot(label: 'G', active: negocio.arGeo != null),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          DsBadge(text: label, tone: tone),
        ],
      ),
    );
  }
}

/// Punto de estado para un recurso AR/360 (ver [_BusinessCard]): "360" =
/// archivo 360°, "M" = modelo AR de marcador, "G" = modelo AR de
/// geolocalización. Solo indica si ya se subió — la gestión real ocurre
/// desde el panel del propio negocio.
class _AssetDot extends StatelessWidget {
  final String label;
  final bool active;

  const _AssetDot({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.brandTeal : AppColors.slate500;
    return Tooltip(
      message: label == '360'
          ? (active ? 'Foto/video 360° subido' : 'Sin foto/video 360°')
          : label == 'M'
              ? (active ? 'Modelo AR de marcador subido' : 'Sin modelo AR de marcador')
              : (active ? 'Modelo AR de geolocalización subido' : 'Sin modelo AR de geolocalización'),
      child: Container(
        width: 22,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : AppColors.overlay(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? color.withOpacity(0.4) : AppColors.overlay(0.1)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
