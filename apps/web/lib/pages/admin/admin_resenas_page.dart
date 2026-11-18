import 'package:flutter/material.dart';

import '../../services/resenas_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/resenas/resenas_widgets.dart';
import '../../widgets/aviso.dart';

/// Cómo se ordenan las reseñas dentro de cada lugar.
enum _Orden { recientes, peores, mejores }

/// Contenido de la sección "Reseñas" embebido en [AdminShell]: las reseñas
/// agrupadas por lugar (o las de un solo lugar), para quitar las que sean
/// ofensivas o spam.
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
  /// Lugar elegido (null = todos, agrupados por lugar).
  String? _lugarId;
  _Orden _orden = _Orden.recientes;

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
      ScaffoldMessenger.of(context).showSnackBar(aviso(e.message, tipo: AvisoTipo.error));
    } finally {
      if (mounted) setState(() => _eliminando.remove(resena.id));
    }
  }

  List<ResenaAdmin> get _filtradas {
    final q = _busqueda.text.trim().toLowerCase();
    final lista = _resenas.where((r) {
      if (_lugarId != null && r.lugarId != _lugarId) return false;
      if (q.isEmpty) return true;
      return r.lugarNombre.toLowerCase().contains(q) ||
          r.autorNombre.toLowerCase().contains(q) ||
          r.autorEmail.toLowerCase().contains(q) ||
          (r.comentario ?? '').toLowerCase().contains(q);
    }).toList();
    lista.sort((a, b) => switch (_orden) {
          _Orden.recientes => b.createdAt.compareTo(a.createdAt),
          _Orden.peores => a.estrellas != b.estrellas
              ? a.estrellas.compareTo(b.estrellas)
              : b.createdAt.compareTo(a.createdAt),
          _Orden.mejores => a.estrellas != b.estrellas
              ? b.estrellas.compareTo(a.estrellas)
              : b.createdAt.compareTo(a.createdAt),
        });
    return lista;
  }

  /// Cada lugar con reseñas: nombre, cuántas tiene y su promedio, por nombre.
  List<_LugarResenas> get _lugares {
    final porLugar = <String, List<ResenaAdmin>>{};
    for (final r in _resenas) {
      porLugar.putIfAbsent(r.lugarId, () => []).add(r);
    }
    return porLugar.entries.map((e) => _LugarResenas(e.key, e.value)).toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
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
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Busqueda(controller: _busqueda),
                _Selector<String?>(
                  key: const ValueKey('filtro-lugar'),
                  valor: _lugarId,
                  opciones: [
                    (null, 'Todos los lugares (${_resenas.length})'),
                    for (final l in _lugares) (l.id, '${l.nombre} (${l.resenas.length})'),
                  ],
                  onChanged: (v) => setState(() => _lugarId = v),
                ),
                _Selector<_Orden>(
                  key: const ValueKey('orden'),
                  valor: _orden,
                  opciones: const [
                    (_Orden.recientes, 'Más recientes'),
                    (_Orden.peores, 'Menor calificación'),
                    (_Orden.mejores, 'Mayor calificación'),
                  ],
                  onChanged: (v) => setState(() => _orden = v ?? _Orden.recientes),
                ),
              ],
            ),
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

    Widget tarjeta(ResenaAdmin r) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _ResenaCard(
            resena: r,
            eliminando: _eliminando.contains(r.id),
            onEliminar: () => _eliminar(r),
          ),
        );

    // Un lugar elegido: solo sus reseñas.
    if (_lugarId != null) return Column(children: lista.map(tarjeta).toList());

    // Todos: un bloque por lugar, con su encabezado (cuántas y promedio).
    final ids = lista.map((r) => r.lugarId).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in _lugares.where((l) => ids.contains(l.id))) ...[
          _EncabezadoLugar(lugar: l, onVerSolo: () => setState(() => _lugarId = l.id)),
          const SizedBox(height: AppSpacing.sm),
          ...lista.where((r) => r.lugarId == l.id).map(tarjeta),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _LugarResenas {
  final String id;
  final List<ResenaAdmin> resenas;

  _LugarResenas(this.id, this.resenas);

  String get nombre => resenas.first.lugarNombre;
  double get promedio => resenas.fold<int>(0, (s, r) => s + r.estrellas) / resenas.length;
}

class _EncabezadoLugar extends StatelessWidget {
  final _LugarResenas lugar;
  final VoidCallback onVerSolo;

  const _EncabezadoLugar({required this.lugar, required this.onVerSolo});

  @override
  Widget build(BuildContext context) {
    final n = lugar.resenas.length;
    return Row(
      children: [
        Icon(Icons.place_outlined, size: 18, color: AppColors.adminViolet),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(lugar.nombre,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.h3),
        ),
        const SizedBox(width: AppSpacing.sm),
        Icon(Icons.star_rounded, size: 16, color: AppColors.amber),
        const SizedBox(width: 2),
        Text('${lugar.promedio.toStringAsFixed(1)} · $n ${n == 1 ? 'reseña' : 'reseñas'}',
            style: AppTypography.bodySmall),
        const Spacer(),
        TextButton(
          onPressed: onVerSolo,
          child: Text('Ver solo este', style: TextStyle(color: AppColors.adminViolet)),
        ),
      ],
    );
  }
}

class _Selector<T> extends StatelessWidget {
  final T valor;
  final List<(T, String)> opciones;
  final ValueChanged<T?> onChanged;

  const _Selector({super.key, required this.valor, required this.opciones, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.buttonLg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: valor,
          dropdownColor: AppColors.panelNavySoft,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.slate400),
          items: [
            for (final (v, texto) in opciones) DropdownMenuItem<T>(value: v, child: Text(texto)),
          ],
          onChanged: onChanged,
        ),
      ),
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
            Text(comentario, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
          ],
          if (respuesta != null && respuesta.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Respuesta del negocio: $respuesta',
                style: TextStyle(color: AppColors.slate400, fontSize: 13, fontStyle: FontStyle.italic, height: 1.4)),
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
