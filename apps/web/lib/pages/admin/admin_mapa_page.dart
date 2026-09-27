import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../models/lugar.dart';
import '../../services/auth_service.dart';
import '../../services/lugares_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/admin/ds_stat_card.dart';
import '../../widgets/admin/ds_table.dart';
import '../../widgets/lugar_preview_card.dart';
import '../../widgets/mapa/mapa_lugares.dart';
import '../lugar_detalle_page.dart';

/// Sección "Mapa y RA" del panel admin: el mapa público tal como lo ve el
/// visitante, la cobertura de experiencias por negocio (con revisión de
/// recursos) y, para el super admin, los parámetros globales.
class AdminMapaPage extends StatefulWidget {
  final AuthUser admin;
  final AuthService authService;
  final LugaresService lugaresService;

  AdminMapaPage({
    super.key,
    required this.admin,
    AuthService? authService,
    this.lugaresService = const LugaresService(),
  }) : authService = authService ?? AuthService();

  @override
  State<AdminMapaPage> createState() => _AdminMapaPageState();
}

class _AdminMapaPageState extends State<AdminMapaPage> {
  final _mapController = MapController();
  List<NegocioSummary> _negocios = [];
  List<Lugar> _lugares = [];
  bool _loading = true;
  String? _error;
  bool _soloIncompletos = false;
  String? _seleccionadoId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mapController.dispose();
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
      final results = await Future.wait([
        widget.authService.adminListNegocios(token),
        widget.lugaresService.listarPublicos(),
      ]);
      if (!mounted) return;
      setState(() {
        _negocios = (results[0] as List<NegocioSummary>).where((n) => n.aprobado).toList();
        _lugares = results[1] as List<Lugar>;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static bool _completo(NegocioSummary n) => n.archivo360 != null && n.arMarcador != null && n.arGeo != null;

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
            Text('Mapa y experiencias', style: AppTypography.h1),
            const SizedBox(height: 4),
            Text('Qué ve el visitante en el mapa y qué experiencias ofrece cada negocio.', style: AppTypography.body),
            const SizedBox(height: AppSpacing.xl),
            if (_loading)
              DsLoadingState()
            else if (_error != null)
              DsErrorState(message: _error!, onRetry: _load)
            else ...[
              _buildStats(),
              const SizedBox(height: AppSpacing.xl),
              _buildMapa(),
              const SizedBox(height: AppSpacing.xl),
              _buildCobertura(),
              const SizedBox(height: AppSpacing.xl),
              _ParametrosCard(
                editable: widget.admin.isSuperAdmin,
                service: widget.lugaresService,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    int cuenta(bool Function(NegocioSummary) f) => _negocios.where(f).length;
    final stats = [
      (Icons.qr_code_scanner, cuenta((n) => n.arMarcador != null), 'Con RA de marcador', ExperienciaInfo.of(ExperienciaTipo.arMarcador).color),
      (Icons.explore_outlined, cuenta((n) => n.arGeo != null), 'Con RA por ubicación', ExperienciaInfo.of(ExperienciaTipo.arGeo).color),
      (Icons.threesixty, cuenta((n) => n.archivo360 != null), 'Con recorrido 360°', ExperienciaInfo.of(ExperienciaTipo.recorrido360).color),
      (Icons.storefront_outlined, cuenta((n) => !_completo(n)), 'Con experiencias pendientes', AppColors.amber),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = Breakpoints.isCompact(constraints.maxWidth) ? 2 : 4;
        return GridView.count(
          crossAxisCount: columnas,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: columnas == 2 ? 1.5 : 1.7,
          children: [
            for (final (icon, value, label, color) in stats)
              DsStatCard(icon: icon, value: value, label: label, accent: color),
          ],
        );
      },
    );
  }

  Widget _buildMapa() {
    Lugar? seleccionado;
    for (final l in _lugares) {
      if (l.id == _seleccionadoId) seleccionado = l;
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
                Expanded(child: Text('Mapa público', style: AppTypography.h3)),
                if (widget.lugaresService.usaDatosDemo)
                  const DsBadge(text: 'Datos de ejemplo', tone: BadgeTone.warning, icon: Icons.science_outlined),
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
                      capaLugares(
                        _lugares,
                        seleccionadoId: _seleccionadoId,
                        onTap: (l) => setState(() => _seleccionadoId = l.id),
                      ),
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
                    child: LugarPreviewCard(
                      lugar: seleccionado,
                      compacta: true,
                      onCerrar: () => setState(() => _seleccionadoId = null),
                      onVerFicha: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => LugarDetallePage(lugar: seleccionado!, vistaPrevia: true)),
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

  Widget _buildCobertura() {
    final filas = _soloIncompletos ? _negocios.where((n) => !_completo(n)).toList() : _negocios;
    const flex = [4, 2, 2, 2, 2];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Experiencias por negocio', style: AppTypography.h2)),
            FilterChip(
              label: const Text('Solo incompletos'),
              selected: _soloIncompletos,
              onSelected: (v) => setState(() => _soloIncompletos = v),
              showCheckmark: false,
              selectedColor: AppColors.adminViolet.withOpacity(0.16),
              checkmarkColor: AppColors.adminViolet,
              labelStyle: TextStyle(
                color: _soloIncompletos ? AppColors.adminViolet : AppColors.slate300,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.surface,
              side: BorderSide(color: AppColors.borderSubtle),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Negocios aprobados. Toca uno para revisar sus recursos.', style: AppTypography.bodySmall),
        const SizedBox(height: AppSpacing.md),
        if (filas.isEmpty)
          const DsEmptyState(
            icon: Icons.view_in_ar_outlined,
            title: 'Nada que mostrar',
            subtitle: 'No hay negocios aprobados con ese filtro.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (Breakpoints.isCompact(constraints.maxWidth)) {
                return Column(
                  children: [
                    for (final n in filas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: DsCard(
                          onTap: () => _revisar(n),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(n.nombre,
                                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                              for (final tipo in ExperienciaTipo.values) ...[
                                const SizedBox(width: 6),
                                _EstadoRecurso(tipo: tipo, activo: _tiene(n, tipo), compacto: true),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              }
              return DsTable(
                headers: const ['NEGOCIO', 'RA MARCADOR', 'RA UBICACIÓN', 'RECORRIDO 360°', ''],
                columnFlex: flex,
                rows: [
                  for (final n in filas)
                    DsTableRow(
                      columnFlex: flex,
                      cells: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.nombre,
                                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(n.categoria ?? 'Sin categoría', style: AppTypography.bodySmall),
                          ],
                        ),
                        for (final tipo in ExperienciaTipo.values) _EstadoRecurso(tipo: tipo, activo: _tiene(n, tipo)),
                        DsButton(label: 'Revisar', size: DsButtonSize.sm, onPressed: () => _revisar(n)),
                      ],
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  static bool _tiene(NegocioSummary n, ExperienciaTipo tipo) => switch (tipo) {
        ExperienciaTipo.arMarcador => n.arMarcador != null,
        ExperienciaTipo.arGeo => n.arGeo != null,
        ExperienciaTipo.recorrido360 => n.archivo360 != null,
      };

  void _revisar(NegocioSummary negocio) {
    showDialog<void>(
      context: context,
      builder: (_) => _RevisionDialog(negocio: negocio, tiene: (t) => _tiene(negocio, t)),
    );
  }
}

class _EstadoRecurso extends StatelessWidget {
  final ExperienciaTipo tipo;
  final bool activo;
  final bool compacto;

  const _EstadoRecurso({required this.tipo, required this.activo, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    final info = ExperienciaInfo.of(tipo);
    if (compacto) {
      return Tooltip(
        message: '${info.tituloCorto}: ${activo ? 'subido' : 'falta'}',
        child: Icon(info.icon, size: 18, color: activo ? info.color : AppColors.slate500.withOpacity(0.5)),
      );
    }
    return activo
        ? const DsBadge(text: 'Subido', tone: BadgeTone.success, icon: Icons.check)
        : const DsBadge(text: 'Falta', tone: BadgeTone.neutral);
  }
}

class _Leyenda extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.panelNavySoft.withOpacity(0.95),
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
                Text(c.etiqueta, style: TextStyle(color: AppColors.textPrimary, fontSize: 11)),
              ],
            ),
        ],
      ),
    );
  }
}

/// Revisión de los recursos de un negocio: el admin aprueba o rechaza cada
/// experiencia antes de que se publique.
class _RevisionDialog extends StatelessWidget {
  final NegocioSummary negocio;
  final bool Function(ExperienciaTipo) tiene;

  const _RevisionDialog({required this.negocio, required this.tiene});

  void _pendiente(BuildContext context, String accion) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$accion todavía no está conectado con el servidor.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panelNavySoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.cardLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REVISAR EXPERIENCIAS', style: AppTypography.caption.copyWith(color: AppColors.adminViolet)),
                        const SizedBox(height: 4),
                        Text(negocio.nombre, style: AppTypography.h2),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AppColors.slate400),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final tipo in ExperienciaTipo.values) ...[
                Builder(builder: (context) {
                  final info = ExperienciaInfo.of(tipo);
                  final activo = tiene(tipo);
                  return DsCard(
                    child: Row(
                      children: [
                        Icon(info.icon, color: activo ? info.color : AppColors.slate500),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(info.tituloCorto, style: AppTypography.h3.copyWith(fontSize: 14)),
                              Text(activo ? 'Archivo subido por el negocio' : 'El negocio no ha subido este recurso',
                                  style: AppTypography.bodySmall),
                            ],
                          ),
                        ),
                        if (activo) ...[
                          DsButton(
                            label: 'Aprobar',
                            size: DsButtonSize.sm,
                            accent: AppColors.emerald,
                            onPressed: () => _pendiente(context, 'Aprobar el recurso'),
                          ),
                          const SizedBox(width: 6),
                          DsButton(
                            label: 'Rechazar',
                            size: DsButtonSize.sm,
                            variant: DsButtonVariant.danger,
                            onPressed: () => _pendiente(context, 'Rechazar el recurso'),
                          ),
                        ] else
                          const DsBadge(text: 'Falta', tone: BadgeTone.neutral),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
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
            activeColor: AppColors.adminViolet,
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
          Switch(value: valor, onChanged: onChanged, activeTrackColor: AppColors.adminViolet),
        ],
      ),
    );
  }
}
