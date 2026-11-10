import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/lugar.dart';
import '../../navegacion/rutas.dart';
import '../../services/ar_service.dart';
import '../../services/auth_service.dart';
import '../../services/ra_geo_service.dart';
import '../../services/recorridos_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/admin_shell.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/admin/seccion_desplegable.dart';
import 'admin_lugar_widgets.dart';
import 'admin_ra_geo_widgets.dart';
import 'admin_recorridos_page.dart';
import '../../widgets/aviso.dart';

/// Un lugar dentro de "Mapa y RA" (`/admin/mapa/lugar/<id>`): sus datos y
/// sus tres experiencias como secciones que se despliegan con una flecha, cada
/// una con su formulario (coordenadas y pin, recorrido 360° con sus escenarios,
/// marcadores de RA).
class AdminLugarPage extends StatefulWidget {
  final String lugarId;
  final AuthService authService;

  AdminLugarPage({super.key, required this.lugarId, AuthService? authService})
      : authService = authService ?? AuthService();

  @override
  State<AdminLugarPage> createState() => _AdminLugarPageState();
}

class _AdminLugarPageState extends State<AdminLugarPage> {
  NegocioSummary? _lugar;
  bool _loading = true;
  String? _error;

  Map<ExperienciaTipo, ConteoExperiencia?> _conteos = const {};

  /// Para abrir (y llevar a la vista) la sección de cada experiencia desde
  /// el resumen.
  final _abiertas = {for (final t in ExperienciaTipo.values) t: ValueNotifier(false)};
  final _llaves = {for (final t in ExperienciaTipo.values) t: GlobalKey()};

  @override
  void dispose() {
    for (final n in _abiertas.values) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarConteos() async {
    final token = SessionStorage.token;
    if (token == null) return;
    final id = widget.lugarId;
    setState(() => _conteos = const {});
    ConteoExperiencia contar(Iterable<bool> activos) =>
        (visibles: activos.where((a) => a).length, total: activos.length);
    Future<ConteoExperiencia?> intentar(Future<ConteoExperiencia> Function() f) => f().then<ConteoExperiencia?>((c) => c).catchError((_) => null);
    final resultados = await Future.wait([
      intentar(() async => contar((await ArService().listMarcadores(token)).where((m) => m.negocioId == id).map((m) => m.activo))),
      intentar(() async => contar((await RaGeoService().listar(token, id)).map((p) => p.activo))),
      intentar(() async => contar((await RecorridosService().listRecorridos(token)).where((r) => r.negocioId == id).map((r) => r.activo))),
    ]);
    if (!mounted) return;
    setState(() => _conteos = {
          ExperienciaTipo.arMarcador: resultados[0],
          ExperienciaTipo.arGeo: resultados[1],
          ExperienciaTipo.recorrido360: resultados[2],
        });
  }

  void _configurar(ExperienciaTipo tipo) {
    _abiertas[tipo]!.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _llaves[tipo]!.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.05);
    });
  }

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarConteos();
  }

  Future<void> _cargar() async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lista = await widget.authService.adminListNegocios(token);
      if (!mounted) return;
      final lugar = lista.where((n) => n.id == widget.lugarId).firstOrNull;
      setState(() {
        _lugar = lugar;
        if (lugar == null) _error = 'Este lugar ya no existe.';
      });
    } catch (err) {
      if (mounted) setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _volver() => context.go(rutaAdmin(AdminSection.mapa));

  /// Lo que ve el visitante: la ficha del lugar en vista previa.
  void _verFicha(NegocioSummary n) {
    abrirLugar(
      context,
      Lugar(
        id: n.id,
        nombre: n.nombre,
        categoriaTexto: n.categoria ?? '',
        descripcion: n.descripcion ?? '',
        direccion: n.direccion,
        portada: 'assets/images/hero-manzanillo.jpg',
        ubicacion: coordenadasDe(n),
      ),
      vistaPrevia: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Arriba a la izquierda aunque haya poco contenido (el panel centra lo
    // que no ocupa toda la altura).
    return Align(
      alignment: Alignment.topLeft,
      child: _contenidoConScroll(),
    );
  }

  Widget _contenidoConScroll() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: _volver,
              icon: Icon(Icons.arrow_back, size: 16, color: AppColors.slate300),
              label: Text('Mapa y RA', style: TextStyle(color: AppColors.slate300)),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_loading)
              DsLoadingState(accent: AppColors.adminViolet)
            else if (_lugar == null)
              DsErrorState(message: _error ?? 'Este lugar ya no existe.', onRetry: _cargar)
            else
              ..._contenido(_lugar!),
          ],
        ),
      ),
    );
  }

  List<Widget> _contenido(NegocioSummary n) {
    final pin = coordenadasDe(n);
    final geo = ExperienciaInfo.of(ExperienciaTipo.arGeo);
    final r360 = ExperienciaInfo.of(ExperienciaTipo.recorrido360);
    final marcador = ExperienciaInfo.of(ExperienciaTipo.arMarcador);
    return [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.md,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.nombre, style: AppTypography.h1),
              const SizedBox(height: 4),
              Text(
                [
                  n.categoria ?? 'Sin categoría',
                  if (n.direccion?.isNotEmpty ?? false) n.direccion!,
                  pin == null ? 'Sin coordenadas' : '$pin',
                ].join(' · '),
                style: AppTypography.body,
              ),
            ],
          ),
          DsButton(
            label: 'Ver ficha',
            icon: Icons.visibility_outlined,
            variant: DsButtonVariant.ghost,
            onPressed: () => _verFicha(n),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),
      _ResumenExperiencias(conteos: _conteos, onConfigurar: _configurar, onRefrescar: _cargarConteos),
      const SizedBox(height: AppSpacing.xl),
      SeccionDesplegable(
        key: const ValueKey('datos'),
        icon: Icons.edit_location_alt_outlined,
        titulo: 'Datos del lugar',
        child: LugarForm(
          lugar: n,
          authService: widget.authService,
          onGuardado: (g) {
            setState(() => _lugar = g);
            ScaffoldMessenger.of(context).showSnackBar(aviso('Lugar guardado'));
          },
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      SeccionDesplegable(
        key: _llaves[ExperienciaTipo.arGeo],
        abierta: _abiertas[ExperienciaTipo.arGeo],
        icon: geo.icon,
        color: geo.color,
        titulo: geo.titulo,
        subtitulo: pin == null ? null : 'Pin: $pin',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UbicacionLugarSection(
              key: ValueKey('geo-${n.latitud}-${n.longitud}'),
              lugar: n,
              authService: widget.authService,
              onGuardado: (g) => setState(() => _lugar = g),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Divider(color: AppColors.borderSubtle, height: 1),
            ),
            // Se vuelve a crear al mover el pin del lugar (el mapa se centra ahí).
            PuntosRaGeoSection(key: ValueKey('puntos-${n.latitud}-${n.longitud}'), lugar: n),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      SeccionDesplegable(
        key: _llaves[ExperienciaTipo.recorrido360],
        abierta: _abiertas[ExperienciaTipo.recorrido360],
        icon: r360.icon,
        color: r360.color,
        titulo: r360.titulo,
        child: RecorridosLugarSection(lugar: n),
      ),
      const SizedBox(height: AppSpacing.md),
      SeccionDesplegable(
        key: _llaves[ExperienciaTipo.arMarcador],
        abierta: _abiertas[ExperienciaTipo.arMarcador],
        icon: marcador.icon,
        color: marcador.color,
        titulo: marcador.titulo,
        child: MarcadoresLugarSection(lugar: n),
      ),
    ];
  }
}

/// Cuántos elementos de una experiencia tiene el lugar y cuántos se ven en la
/// app (null = todavía cargando o sin conexión).
typedef ConteoExperiencia = ({int visibles, int total});

/// "Experiencias de este lugar": las tres de un vistazo, con su estado
/// (visible para los visitantes, oculta o sin configurar) y un botón que
/// abre su sección para activarla o desactivarla.
class _ResumenExperiencias extends StatelessWidget {
  final Map<ExperienciaTipo, ConteoExperiencia?> conteos;
  final ValueChanged<ExperienciaTipo> onConfigurar;
  final VoidCallback onRefrescar;

  const _ResumenExperiencias({required this.conteos, required this.onConfigurar, required this.onRefrescar});

  static String _unidad(ExperienciaTipo tipo, int n) => switch (tipo) {
        ExperienciaTipo.arMarcador => n == 1 ? 'marcador' : 'marcadores',
        ExperienciaTipo.arGeo => n == 1 ? 'punto de RA' : 'puntos de RA',
        ExperienciaTipo.recorrido360 => n == 1 ? 'recorrido' : 'recorridos',
      };

  @override
  Widget build(BuildContext context) {
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Experiencias de este lugar', style: AppTypography.h2)),
              IconButton(
                tooltip: 'Actualizar estado',
                onPressed: onRefrescar,
                icon: Icon(Icons.refresh, color: AppColors.slate300),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Una experiencia está activa cuando tiene al menos un elemento visible. Cada marcador, punto de RA '
            'o recorrido tiene su propio interruptor "Visible / Oculto" dentro de su sección.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columnas = constraints.maxWidth >= 720 ? 3 : 1;
              const espacio = AppSpacing.md;
              final ancho = (constraints.maxWidth - espacio * (columnas - 1)) / columnas;
              return Wrap(
                spacing: espacio,
                runSpacing: espacio,
                children: [
                  for (final tipo in const [ExperienciaTipo.arGeo, ExperienciaTipo.recorrido360, ExperienciaTipo.arMarcador])
                    SizedBox(width: ancho, child: _tile(tipo)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(ExperienciaTipo tipo) {
    final info = ExperienciaInfo.of(tipo);
    final conteo = conteos[tipo];
    final (estado, color, detalle) = switch (conteo) {
      null => ('Cargando…', AppColors.slate400, ''),
      (total: 0, visibles: _) => ('Sin configurar', AppColors.slate400, 'Todavía no tiene ningún elemento.'),
      (visibles: 0, total: final t) => ('Oculta', AppColors.amarilloTexto, '$t ${_unidad(tipo, t)}, ninguno visible.'),
      (visibles: final v, total: final t) =>
        ('Activa', AppColors.emerald, '$v de $t ${_unidad(tipo, t)} visibles en la app.'),
    };
    // Fondo neutro: el color de la experiencia ya va en su ícono, y el
    // fondo tintado hacía que "Sin configurar" en rojo pareciera un error.
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cubierta,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(info.icon, color: info.color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(info.tituloCorto, style: AppTypography.h3.copyWith(fontSize: 15))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(estado, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          if (detalle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(detalle, style: AppTypography.caption.copyWith(color: AppColors.slate400)),
          ],
          const SizedBox(height: AppSpacing.md),
          DsButton(
            label: conteo?.total == 0 ? 'Agregar' : 'Gestionar',
            icon: conteo?.total == 0 ? Icons.add : Icons.tune,
            size: DsButtonSize.sm,
            accent: info.color,
            onPressed: () => onConfigurar(tipo),
          ),
        ],
      ),
    );
  }
}
