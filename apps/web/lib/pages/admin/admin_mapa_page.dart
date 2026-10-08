import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';

import '../../models/lugar.dart';
import '../../navegacion/rutas.dart';
import '../../services/auth_service.dart';
import '../../services/lugares_service.dart';
import '../../services/recorridos_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/admin/seccion_desplegable.dart';
import '../../widgets/mapa/mapa_lugares.dart';
import 'admin_lugar_page.dart';
import 'admin_lugar_widgets.dart';

/// Sección "Mapa y RA" del panel admin (`/admin/mapa`): registrar lugares con
/// sus coordenadas, verlos en el mapa y, al tocar "Revisar", abrir la página
/// del lugar (`/admin/mapa/lugar/<id>`) con su RA por ubicación, su recorrido
/// 360° y sus marcadores. Para el super admin, los parámetros globales.
class AdminMapaPage extends StatefulWidget {
  final AuthUser admin;
  final AuthService authService;
  final LugaresService lugaresService;
  final RecorridosService recorridosService;

  /// Lugar abierto (viene de la URL). null = la lista de lugares.
  final String? lugarId;

  AdminMapaPage({
    super.key,
    required this.admin,
    AuthService? authService,
    RecorridosService? recorridosService,
    this.lugaresService = const LugaresService(),
    this.lugarId,
  })  : authService = authService ?? AuthService(),
        recorridosService = recorridosService ?? RecorridosService();

  @override
  State<AdminMapaPage> createState() => _AdminMapaPageState();
}

class _AdminMapaPageState extends State<AdminMapaPage> {
  final _mapController = MapController();
  final _registroAbierto = ValueNotifier(false);
  List<NegocioSummary> _lugares = [];
  List<Recorrido360> _recorridos = [];
  bool _loading = true;
  String? _error;
  String? _seleccionadoId;
  String? _editandoId;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    if (widget.lugarId == null) _load();
  }

  @override
  void didUpdateWidget(AdminMapaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // De vuelta del detalle de un lugar: recargar por si cambió algo.
    if (oldWidget.lugarId != null && widget.lugarId == null) _load();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _registroAbierto.dispose();
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
      final lugares = await widget.authService.adminListNegocios(token);
      // Si fallan los recorridos, los lugares se siguen mostrando.
      final recorridos = await widget.recorridosService.listRecorridos(token).catchError((_) => <Recorrido360>[]);
      if (!mounted) return;
      setState(() {
        _lugares = lugares.where((n) => n.aprobado).toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        _recorridos = recorridos;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _revisar(NegocioSummary n) => context.go(rutaLugarAdmin(n.id));

  void _snack(String texto) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _eliminar(NegocioSummary n) async {
    final recorridos = _recorridos.where((r) => r.negocioId == n.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Eliminar "${n.nombre}"', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Se borrará el lugar'
          '${recorridos > 0 ? ', sus $recorridos ${recorridos == 1 ? 'recorrido' : 'recorridos'} 360°' : ''}'
          ' y sus marcadores.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancelar', style: TextStyle(color: AppColors.slate400))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Eliminar', style: TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );
    if (ok != true) return;
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _busy.add(n.id));
    try {
      await widget.authService.adminEliminarLugar(token, n.id);
      if (!mounted) return;
      _snack('"${n.nombre}" se eliminó');
      await _load();
    } catch (err) {
      _snack(err is AuthError ? err.message : 'No se pudo eliminar el lugar');
    } finally {
      if (mounted) setState(() => _busy.remove(n.id));
    }
  }

  Future<void> _asignarRecorrido(Recorrido360 r, String lugarId) async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _busy.add(r.id));
    try {
      await widget.recorridosService.updateRecorrido(token, r.id, {'negocioId': lugarId});
      await _load();
    } catch (err) {
      _snack(err is AuthError ? err.message : 'No se pudo asignar el recorrido');
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  Future<void> _eliminarRecorrido(Recorrido360 r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Eliminar recorrido', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('"${r.titulo}" y sus ${r.escenas.length} escenarios dejarán de estar en la app.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancelar', style: TextStyle(color: AppColors.slate400))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Eliminar', style: TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );
    if (ok != true) return;
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _busy.add(r.id));
    try {
      await widget.recorridosService.deleteRecorrido(token, r.id);
      await _load();
    } catch (err) {
      _snack(err is AuthError ? err.message : 'No se pudo eliminar el recorrido');
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lugarId = widget.lugarId;
    if (lugarId != null) {
      return AdminLugarPage(key: ValueKey(lugarId), lugarId: lugarId, authService: widget.authService);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.adminViolet,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mapa y RA', style: AppTypography.h1),
              const SizedBox(height: AppSpacing.xl),
              SeccionDesplegable(
                icon: Icons.add_location_alt_outlined,
                titulo: 'Registrar lugar',
                abierta: _registroAbierto,
                child: LugarForm(
                  authService: widget.authService,
                  onGuardado: (n) {
                    _registroAbierto.value = false;
                    _snack('"${n.nombre}" registrado');
                    _load();
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_loading)
                DsLoadingState(accent: AppColors.adminViolet)
              else if (_error != null)
                DsErrorState(message: _error!, onRetry: _load)
              else ...[
                _buildMapa(),
                const SizedBox(height: AppSpacing.xl),
                _buildLugares(),
                if (_recorridos.any((r) => r.negocioId == null)) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _buildSinLugar(),
                ],
                const SizedBox(height: AppSpacing.xl),
                _ParametrosCard(editable: widget.admin.isSuperAdmin, service: widget.lugaresService),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Lugares registrados con pin, como los verá el visitante.
  List<Lugar> get _pines => [
        for (final n in _lugares)
          if (n.tieneUbicacion)
            Lugar(id: n.id, nombre: n.nombre, categoriaTexto: n.categoria ?? '', portada: '', ubicacion: coordenadasDe(n)),
      ];

  Widget _buildMapa() {
    final pines = _pines;
    NegocioSummary? seleccionado;
    for (final n in _lugares) {
      if (n.id == _seleccionadoId) seleccionado = n;
    }

    return DsCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(Icons.map_outlined, color: AppColors.adminViolet),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text('Mapa de lugares', style: AppTypography.h3)),
                Text('${pines.length} de ${_lugares.length} con pin', style: AppTypography.bodySmall),
              ],
            ),
          ),
          SizedBox(
            height: 420,
            child: Stack(
              children: [
                Positioned.fill(
                  child: MapaBase(
                    controller: _mapController,
                    onTap: (_) => setState(() => _seleccionadoId = null),
                    children: [
                      capaLugares(pines, seleccionadoId: _seleccionadoId, onTap: (l) => setState(() => _seleccionadoId = l.id)),
                    ],
                  ),
                ),
                Positioned(right: 12, bottom: 24, child: ControlesMapa(controller: _mapController)),
                Positioned(left: 12, bottom: 24, child: _Leyenda()),
                if (seleccionado != null)
                  Positioned(
                    left: 12,
                    top: 12,
                    width: 300,
                    child: DsCard(
                      background: AppColors.panelNavySoft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(seleccionado.nombre, style: AppTypography.h3)),
                              InkWell(
                                onTap: () => setState(() => _seleccionadoId = null),
                                child: Icon(Icons.close, size: 18, color: AppColors.slate400),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [seleccionado.categoria ?? 'Sin categoría', if (seleccionado.direccion?.isNotEmpty ?? false) seleccionado.direccion!]
                                .join(' · '),
                            style: AppTypography.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          DsButton(
                            label: 'Revisar',
                            icon: Icons.arrow_forward,
                            size: DsButtonSize.sm,
                            variant: DsButtonVariant.primary,
                            accent: AppColors.adminViolet,
                            onPressed: () => _revisar(seleccionado!),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLugares() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Lugares', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.md),
        if (_lugares.isEmpty)
          const DsEmptyState(
            icon: Icons.place_outlined,
            title: 'Sin lugares',
            subtitle: '',
          )
        else
          for (final n in _lugares)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _FilaLugar(
                lugar: n,
                recorridos: _recorridos.where((r) => r.negocioId == n.id).length,
                busy: _busy.contains(n.id),
                editando: _editandoId == n.id,
                authService: widget.authService,
                onRevisar: () => _revisar(n),
                onEditar: () => setState(() => _editandoId = _editandoId == n.id ? null : n.id),
                onGuardado: (_) {
                  setState(() => _editandoId = null);
                  _snack('Lugar guardado');
                  _load();
                },
                onEliminar: () => _eliminar(n),
              ),
            ),
      ],
    );
  }

  Widget _buildSinLugar() {
    final huerfanos = _recorridos.where((r) => r.negocioId == null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Recorridos sin lugar', style: AppTypography.h2),
        const SizedBox(height: AppSpacing.md),
        for (final r in huerfanos)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: DsCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 96,
                      height: 48,
                      child: r.escenas.isEmpty
                          ? ColoredBox(color: AppColors.surface, child: Icon(Icons.threesixty, color: AppColors.slate500))
                          : Image.network(r.escenas.first.miniaturaUrl, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.titulo, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('${r.nombre} · ${r.escenas.length} escenarios', style: AppTypography.caption),
                      ],
                    ),
                  ),
                  if (_busy.contains(r.id))
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.adminViolet))
                  else ...[
                    PopupMenuButton<String>(
                      tooltip: 'Asignar a un lugar',
                      color: AppColors.panelNavySoft,
                      enabled: _lugares.isNotEmpty,
                      onSelected: (id) => _asignarRecorrido(r, id),
                      itemBuilder: (_) => [
                        for (final n in _lugares)
                          PopupMenuItem(value: n.id, child: Text(n.nombre, style: TextStyle(color: AppColors.textPrimary))),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.place_outlined, size: 16, color: AppColors.adminViolet),
                            const SizedBox(width: 4),
                            Text('Asignar a…', style: TextStyle(color: AppColors.adminViolet, fontSize: 13, fontWeight: FontWeight.w600)),
                            Icon(Icons.arrow_drop_down, color: AppColors.adminViolet),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: () => _eliminarRecorrido(r),
                      icon: Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Un lugar de la lista: su nombre y datos, y "Revisar", editar (el
/// formulario se despliega debajo) y eliminar.
class _FilaLugar extends StatelessWidget {
  final NegocioSummary lugar;
  final int recorridos;
  final bool busy;
  final bool editando;
  final AuthService authService;
  final VoidCallback onRevisar;
  final VoidCallback onEditar;
  final ValueChanged<NegocioSummary> onGuardado;
  final VoidCallback onEliminar;

  const _FilaLugar({
    required this.lugar,
    required this.recorridos,
    required this.busy,
    required this.editando,
    required this.authService,
    required this.onRevisar,
    required this.onEditar,
    required this.onGuardado,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final n = lugar;
    final cat = CategoriaLugarDetector.detectar(n.categoria);
    return DsCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
                child: Icon(cat.icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.nombre, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      [n.categoria ?? 'Sin categoría', if (n.direccion?.isNotEmpty ?? false) n.direccion!].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        n.tieneUbicacion
                            ? const DsBadge(text: 'Con pin', tone: BadgeTone.success, icon: Icons.location_on)
                            : const DsBadge(text: 'Sin coordenadas', tone: BadgeTone.warning, icon: Icons.location_off_outlined),
                        if (recorridos > 0)
                          DsBadge(text: '$recorridos 360°', tone: BadgeTone.info, icon: Icons.threesixty),
                      ],
                    ),
                  ],
                ),
              ),
              if (busy)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.adminViolet)),
                )
              else ...[
                DsButton(
                  label: 'Revisar',
                  size: DsButtonSize.sm,
                  variant: DsButtonVariant.primary,
                  accent: AppColors.adminViolet,
                  onPressed: onRevisar,
                ),
                IconButton(
                  tooltip: editando ? 'Cerrar edición' : 'Editar datos',
                  onPressed: onEditar,
                  icon: Icon(editando ? Icons.expand_less : Icons.edit_outlined, size: 18, color: AppColors.slate300),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: onEliminar,
                  icon: Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                ),
              ],
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: editando
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: LugarForm(lugar: n, authService: authService, onGuardado: onGuardado, onCancelar: onEditar),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.panelNavySoft.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Wrap(
        direction: Axis.vertical,
        spacing: 4,
        children: [
          for (final c in CategoriaLugar.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(c.etiqueta, style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }
}


/// Parámetros globales de las experiencias. Todos los admins los ven; solo
/// el super admin los edita.
class _ParametrosCard extends StatefulWidget {
  final bool editable;
  final LugaresService service;

  const _ParametrosCard({required this.editable, required this.service});

  @override
  State<_ParametrosCard> createState() => _ParametrosCardState();
}

class _ParametrosCardState extends State<_ParametrosCard> {
  ConfigExperiencias _config = const ConfigExperiencias();

  Future<void> _guardar() async {
    try {
      await widget.service.guardarConfigExperiencias(_config);
    } on PendienteBackend catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = widget.editable;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: AppColors.adminViolet),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text('Parámetros de experiencias', style: AppTypography.h3)),
              if (!editable) const DsBadge(text: 'Solo super admin', tone: BadgeTone.neutral, icon: Icons.lock_outline),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: Text('Radio de desbloqueo por defecto', style: AppTypography.body)),
              Text('${_config.radioDesbloqueoDefault.round()} m',
                  style: TextStyle(color: AppColors.adminViolet, fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: _config.radioDesbloqueoDefault,
            min: 20,
            max: 300,
            divisions: 28,
            onChanged: editable ? (v) => setState(() => _config = _config.copyWith(radioDesbloqueoDefault: v)) : null,
          ),
          _SwitchFila(
            titulo: 'Revisar recursos antes de publicarlos',
            detalle: 'Un admin aprueba cada archivo nuevo antes de que lo vean los visitantes.',
            valor: _config.revisionObligatoria,
            onChanged: editable ? (v) => setState(() => _config = _config.copyWith(revisionObligatoria: v)) : null,
          ),
          _SwitchFila(
            titulo: 'Mostrar en el mapa negocios sin experiencias',
            detalle: 'Si se apaga, solo aparecen los lugares con RA o recorrido 360°.',
            valor: _config.mostrarSinExperiencias,
            onChanged: editable ? (v) => setState(() => _config = _config.copyWith(mostrarSinExperiencias: v)) : null,
          ),
          if (editable) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: DsButton(label: 'Guardar parámetros', icon: Icons.check, variant: DsButtonVariant.primary, onPressed: _guardar),
            ),
          ],
        ],
      ),
    );
  }
}

class _SwitchFila extends StatelessWidget {
  final String titulo;
  final String detalle;
  final bool valor;
  final ValueChanged<bool>? onChanged;

  const _SwitchFila({required this.titulo, required this.detalle, required this.valor, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppTypography.body.copyWith(color: AppColors.textPrimary)),
                Text(detalle, style: AppTypography.bodySmall),
              ],
            ),
          ),
          Switch(value: valor, onChanged: onChanged),
        ],
      ),
    );
  }
}
