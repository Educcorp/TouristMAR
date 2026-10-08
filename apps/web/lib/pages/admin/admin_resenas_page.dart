import 'package:flutter/material.dart';

import '../../services/resenas_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/resenas/resenas_widgets.dart';

/// Contenido de la sección "Reseñas" embebido en [AdminShell]: todas las
/// reseñas de los lugares, para quitar las que sean ofensivas o spam.
class AdminResenasPage extends StatefulWidget {
  final ResenasService service;

  AdminResenasPage({super.key, ResenasService? service}) : service = service ?? ResenasService();

  @override
  State<AdminResenasPage> createState() => _AdminResenasPageState();
}

class _AdminResenasPageState extends State<AdminResenasPage> {
  final _busqueda = TextEditingController();
  List<ResenaAdmin> _resenas = [];
  bool _cargando = true;
  String? _error;
  final Set<String> _eliminando = {};

  @override
  void initState() {
    super.initState();
    _cargar();
    _busqueda.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resenas = await widget.service.adminListar();
      if (!mounted) return;
      setState(() => _resenas = resenas);
    } on ResenasError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminar(ResenaAdmin resena) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Eliminar reseña', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Se eliminará la reseña de ${resena.autorNombre} sobre ${resena.lugarNombre}. Esta acción no se puede deshacer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.rojo, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _eliminando.add(resena.id));
    try {
      await widget.service.adminBorrar(resena.id);
      if (!mounted) return;
      setState(() => _resenas.removeWhere((r) => r.id == resena.id));
    } on ResenasError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _eliminando.remove(resena.id));
    }
  }

  List<ResenaAdmin> get _filtradas {
    final q = _busqueda.text.trim().toLowerCase();
    if (q.isEmpty) return _resenas;
    return _resenas
        .where((r) =>
            r.lugarNombre.toLowerCase().contains(q) ||
            r.autorNombre.toLowerCase().contains(q) ||
            r.autorEmail.toLowerCase().contains(q) ||
            (r.comentario ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargar,
      color: AppColors.adminViolet,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Reseñas', style: AppTypography.h1),
                const SizedBox(width: AppSpacing.sm),
                DsBadge(text: '${_resenas.length}', tone: BadgeTone.info),
              ],
            ),
            const SizedBox(height: 4),
            Text('Revisa las reseñas de los lugares y elimina las que no cumplan las reglas.', style: AppTypography.body),
            const SizedBox(height: AppSpacing.lg),
            _Busqueda(controller: _busqueda),
            const SizedBox(height: AppSpacing.xl),
            _contenido(),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) return DsLoadingState();
    if (_error != null) return DsErrorState(message: _error!, onRetry: _cargar);
    if (_resenas.isEmpty) {
      return const DsEmptyState(
        icon: Icons.forum_outlined,
        title: 'Aún no hay reseñas',
        subtitle: 'Cuando los visitantes califiquen los lugares, aparecerán aquí.',
      );
    }
    final lista = _filtradas;
    if (lista.isEmpty) {
      return const DsEmptyState(
        icon: Icons.search_off_outlined,
        title: 'Sin coincidencias',
        subtitle: 'Ninguna reseña coincide con tu búsqueda.',
      );
    }

    return Column(
      children: lista
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ResenaCard(
                  resena: r,
                  eliminando: _eliminando.contains(r.id),
                  onEliminar: () => _eliminar(r),
                ),
              ))
          .toList(),
    );
  }
}

class _Busqueda extends StatelessWidget {
  final TextEditingController controller;

  const _Busqueda({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: TextField(
        controller: controller,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Buscar por lugar, autor o comentario…',
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
    );
  }
}

class _ResenaCard extends StatelessWidget {
  final ResenaAdmin resena;
  final bool eliminando;
  final VoidCallback onEliminar;

  const _ResenaCard({required this.resena, required this.eliminando, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    final comentario = resena.comentario;
    final respuesta = resena.respuesta;

    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(resena.lugarNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('${resena.autorNombre} · ${resena.autorEmail} · ${resena.fecha}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              EstrellasFila(valor: resena.estrellas, size: 14),
            ],
          ),
          if (comentario != null && comentario.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(comentario, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
          ],
          if (respuesta != null && respuesta.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Respuesta del negocio: $respuesta',
                style: TextStyle(color: AppColors.slate400, fontSize: 12, fontStyle: FontStyle.italic, height: 1.4)),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: eliminando
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate400))
                : DsButton(
                    label: 'Eliminar',
                    icon: Icons.delete_outline,
                    variant: DsButtonVariant.danger,
                    size: DsButtonSize.sm,
                    onPressed: onEliminar,
                  ),
          ),
        ],
      ),
    );
  }
}
