import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/lugar.dart';
import '../../navegacion/rutas.dart';
import '../../services/auth_service.dart';
import '../../services/categorias_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_icon_badge.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/aviso.dart';
import 'admin_categorias_dialog.dart';
import 'admin_negocio_detalle_page.dart';

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
  /// Filtro por categoría (null = todas).
  String? _categoria;
  List<String> _categorias = const [];

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
      final (negocios, categorias) =
          await (widget.authService.adminListNegocios(token), CategoriasService().nombres(refrescar: true)).wait;
      if (!mounted) return;
      setState(() {
        _negocios = negocios;
        _categorias = categorias;
        if (_categoria != null && !_opcionesCategoria.contains(_categoria)) _categoria = null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Detalle del negocio, editable por el admin (misma pantalla que usa
  /// "Solicitudes" — ahí además puede aprobar/rechazar, aquí esos botones no
  /// aparecen porque el negocio ya no está pendiente).
  Future<void> _abrirDetalle(NegocioSummary negocio) async {
    final resultado = await abrirDetalleNegocio(context, negocioId: negocio.id, authService: widget.authService);
    if (!mounted || resultado == null) return;
    if (resultado.abrirContenido != null) {
      context.go(rutaLugarAdmin(negocio.id));
      return;
    }
    if (resultado.editado || resultado.aprobado != null) _load();
  }

  /// Eliminar desde el catálogo (antes solo se podía desde "Mapa y RA").
  Future<void> _eliminar(NegocioSummary negocio) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Eliminar "${negocio.nombre}"', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Se borran el negocio, sus reseñas, favoritos, marcadores de RA y recorridos 360°. No se puede deshacer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Eliminar', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final token = SessionStorage.token;
    if (token == null) return;
    try {
      await widget.authService.adminEliminarLugar(token, negocio.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(aviso('"${negocio.nombre}" se eliminó'));
      _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(aviso(err is AuthError ? err.message : 'No se pudo eliminar el negocio', tipo: AvisoTipo.error));
    }
  }

  Future<void> _gestionarCategorias() async {
    await mostrarCategoriasAdmin(context);
    if (mounted) _load();
  }

  /// Las categorías administrables más las que usan los negocios aunque no
  /// estén en la lista (texto libre de "Otro").
  List<String> get _opcionesCategoria {
    final opciones = [..._categorias];
    final enMinusculas = opciones.map((c) => c.toLowerCase()).toSet();
    for (final n in _negocios) {
      final c = (n.categoria ?? '').trim();
      if (c.isNotEmpty && enMinusculas.add(c.toLowerCase())) opciones.add(c);
    }
    return opciones;
  }

  List<NegocioSummary> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    final categoria = _categoria?.toLowerCase();
    return _negocios.where((n) {
      if (categoria != null && (n.categoria ?? '').trim().toLowerCase() != categoria) return false;
      if (query.isNotEmpty &&
          !n.nombre.toLowerCase().contains(query) &&
          !(n.categoria ?? '').toLowerCase().contains(query)) {
        return false;
      }
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
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar negocio por nombre o categoría…',
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.buttonLg),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              key: const ValueKey('filtro-categoria'),
              value: _categoria,
              dropdownColor: AppColors.panelNavySoft,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              icon: Icon(Icons.keyboard_arrow_down, color: AppColors.slate400),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Todas las categorías')),
                for (final c in _opcionesCategoria)
                  DropdownMenuItem<String?>(
                    value: c,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CategoriaLugarDetector.detectar(c).icon, size: 16, color: AppColors.slate400),
                        const SizedBox(width: 8),
                        Text('$c (${_negocios.where((n) => (n.categoria ?? '').trim().toLowerCase() == c.toLowerCase()).length})'),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _categoria = v),
            ),
          ),
        ),
        DsButton(
          label: 'Categorías',
          icon: Icons.category_outlined,
          variant: DsButtonVariant.secondary,
          accent: AppColors.adminViolet,
          onPressed: _gestionarCategorias,
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
        subtitle: 'Prueba con otra búsqueda o espera nuevos registros.',
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
            return SizedBox(
              width: width,
              child: _BusinessCard(negocio: n, onEdit: () => _abrirDetalle(n), onDelete: () => _eliminar(n)),
            );
          }).toList(),
        );
      },
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final NegocioSummary negocio;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BusinessCard({required this.negocio, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final tone = switch (negocio.estado) {
      'aprobado' => BadgeTone.success,
      'rechazado' => BadgeTone.danger,
      _ => BadgeTone.warning,
    };
    final label = _estadoLabels[negocio.estado] ?? 'Pendiente';

    return DsCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ícono según la categoría (playa, restaurante, hotel…) para
              // distinguirlos de un vistazo.
              DsIconBadgeCircle(
                icon: CategoriaLugarDetector.detectar(negocio.categoria ?? '').icon,
                color: CategoriaLugarDetector.detectar(negocio.categoria ?? '').color,
                size: 40,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(negocio.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(negocio.categoria ?? 'Sin categoría', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              DsBadge(text: label, tone: tone),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _AssetDot(tipo: ExperienciaTipo.recorrido360, active: negocio.archivo360 != null),
              const SizedBox(width: 4),
              _AssetDot(tipo: ExperienciaTipo.arMarcador, active: negocio.arMarcador != null),
              const SizedBox(width: 4),
              _AssetDot(tipo: ExperienciaTipo.arGeo, active: negocio.arGeo != null),
              const Spacer(),
              IconButton(
                tooltip: 'Eliminar negocio',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, size: 20, color: AppColors.errorRed),
              ),
              const SizedBox(width: 4),
              DsButton(
                label: 'Editar',
                icon: Icons.edit_outlined,
                size: DsButtonSize.sm,
                accent: AppColors.adminViolet,
                onPressed: onEdit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Si el negocio ya tiene cada experiencia (marcador, ubicación, 360°): su
/// ícono a color cuando sí y apagado cuando no, con la explicación al pasar el
/// cursor. Antes eran las letras "360", "M" y "G" en cajitas, que nadie sabía
/// leer (y "360" ya no cabía con la letra nueva).
class _AssetDot extends StatelessWidget {
  final ExperienciaTipo tipo;
  final bool active;

  const _AssetDot({required this.tipo, required this.active});

  @override
  Widget build(BuildContext context) {
    final info = ExperienciaInfo.of(tipo);
    return Tooltip(
      message: '${info.titulo}: ${active ? 'activa' : 'sin configurar'}',
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceAlt : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? Colors.transparent : AppColors.borderSubtle),
        ),
        child: Icon(info.icon, size: 18, color: active ? info.color : AppColors.slate500.withValues(alpha: 0.6)),
      ),
    );
  }
}
