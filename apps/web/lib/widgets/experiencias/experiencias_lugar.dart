import 'package:flutter/material.dart';

import '../../models/lugar.dart';
import '../../services/experiencias_launcher.dart';
import '../../services/ra_geo_service.dart' show radioCercanoDefault, radioVisibleDefault;
import '../../services/recorridos_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../theme/theme_controller.dart';
import '../mapa/mapa_lugares.dart';
import '../recorrido360/visor_360.dart';
import 'experiencia_viewport.dart';

/// Estado calculado de una experiencia para un visitante concreto.
class ExperienciaSituacion {
  final ExperienciaTipo tipo;
  final ExperienciaEstado estado;

  /// Solo para [ExperienciaTipo.arGeo]: distancia actual al lugar, o `null`
  /// si no se conoce la ubicación del visitante.
  final double? distancia;

  const ExperienciaSituacion(this.tipo, this.estado, {this.distancia});

  /// [tieneRecorrido360] = si el lugar tiene su propio recorrido publicado
  /// (lo dice la API, no `lugar.archivo360`); `null` = usar el del lugar.
  static ExperienciaSituacion calcular(Lugar lugar, ExperienciaTipo tipo, Coordenadas? yo, {bool? tieneRecorrido360}) {
    final tiene = switch (tipo) {
      ExperienciaTipo.recorrido360 => tieneRecorrido360 ?? lugar.tiene(tipo),
      // Cualquier lugar con pin en el mapa (sus puntos de RA, o el pin
      // mismo como punto único; ver RaUbicacionPage).
      ExperienciaTipo.arGeo => lugar.ubicacion != null,
      ExperienciaTipo.arMarcador => lugar.tiene(tipo),
    };
    if (!tiene) return ExperienciaSituacion(tipo, ExperienciaEstado.noDisponible);
    if (tipo != ExperienciaTipo.arGeo) return ExperienciaSituacion(tipo, ExperienciaEstado.disponible);
    // El visor de RA por ubicación ya calcula la distancia: se deja abrir siempre.
    if (ExperienciasLauncher.current.mideDistancia(tipo)) return ExperienciaSituacion(tipo, ExperienciaEstado.disponible);

    final destino = lugar.ubicacion;
    if (yo == null || destino == null) return ExperienciaSituacion(tipo, ExperienciaEstado.bloqueada);
    final d = distanciaMetros(yo, destino);
    return ExperienciaSituacion(
      tipo,
      d <= lugar.radioDesbloqueo ? ExperienciaEstado.disponible : ExperienciaEstado.bloqueada,
      distancia: d,
    );
  }
}

/// Sección "Experiencias inmersivas" de la ficha de un lugar: las tres
/// tarjetas (RA marcador, RA ubicación, recorrido 360°) y, al tocarlas, su
/// detalle con el visor. [vistaPrevia] = el negocio o un admin la ven tal
/// cual la verá un visitante, pero los botones no lanzan nada.
class ExperienciasLugarSection extends StatefulWidget {
  final Lugar lugar;
  final bool vistaPrevia;
  final RecorridosService? recorridosService;

  const ExperienciasLugarSection({super.key, required this.lugar, this.vistaPrevia = false, this.recorridosService});

  @override
  State<ExperienciasLugarSection> createState() => _ExperienciasLugarSectionState();
}

class _ExperienciasLugarSectionState extends State<ExperienciasLugarSection> {
  Coordenadas? _yo;

  /// Si el lugar tiene su propio recorrido 360° publicado. Hasta que responda
  /// la API (o si falla) la tarjeta se muestra sin recorrido: nunca se toma
  /// el de otro lugar.
  bool _tieneRecorrido360 = false;

  @override
  void initState() {
    super.initState();
    _cargarRecorrido360();
  }

  @override
  void didUpdateWidget(ExperienciasLugarSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lugar.id != widget.lugar.id || oldWidget.lugar.nombre != widget.lugar.nombre) {
      _tieneRecorrido360 = false;
      _cargarRecorrido360();
    }
  }

  Future<void> _cargarRecorrido360() async {
    try {
      final recorridos = await (widget.recorridosService ?? RecorridosService()).listPublicos();
      final propio = recorridoDeLugar(recorridos, lugarId: widget.lugar.id, lugarNombre: widget.lugar.nombre);
      if (mounted) setState(() => _tieneRecorrido360 = propio != null);
    } catch (_) {
      // Sin conexión: se queda sin recorrido.
    }
  }

  ExperienciaSituacion _situacion(ExperienciaTipo tipo, Coordenadas? yo) =>
      ExperienciaSituacion.calcular(widget.lugar, tipo, yo, tieneRecorrido360: _tieneRecorrido360);

  Future<void> _activarUbicacion() async {
    final yo = await UbicacionProvider.current.actual();
    if (!mounted) return;
    setState(() => _yo = yo);
    if (yo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener tu ubicación. Activa la ubicación y permite el acceso.')),
      );
    }
  }

  void _abrirDetalle(ExperienciaSituacion situacion) {
    mostrarDetalleExperiencia(
      context,
      lugar: widget.lugar,
      situacion: situacion,
      vistaPrevia: widget.vistaPrevia,
      onActivarUbicacion: _activarUbicacion,
      recalcular: _situacion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final situaciones = [
      for (final tipo in ExperienciaTipo.values) _situacion(tipo, _yo),
    ];
    final disponibles = situaciones.where((s) => s.estado != ExperienciaEstado.noDisponible).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.view_in_ar_outlined, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: AppSpacing.sm),
            Text('Experiencias inmersivas', style: AppTypography.h3),
            const Spacer(),
            Text(
              '$disponibles de 3 disponibles',
              style: AppTypography.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columnas = constraints.maxWidth >= 640 ? 3 : 1;
            final ancho = columnas == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - AppSpacing.md * (columnas - 1)) / columnas;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final s in situaciones)
                  SizedBox(
                    width: ancho,
                    child: ExperienciaCard(
                      situacion: s,
                      lugar: widget.lugar,
                      compacta: columnas == 1,
                      onTap: s.estado == ExperienciaEstado.noDisponible ? null : () => _abrirDetalle(s),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Tarjeta de una experiencia en la ficha del lugar.
class ExperienciaCard extends StatelessWidget {
  final ExperienciaSituacion situacion;
  final Lugar lugar;
  final bool compacta;
  final VoidCallback? onTap;

  const ExperienciaCard({
    super.key,
    required this.situacion,
    required this.lugar,
    this.compacta = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final info = ExperienciaInfo.of(situacion.tipo);
    final apagada = situacion.estado == ExperienciaEstado.noDisponible;
    final color = apagada ? AppColors.slate500 : info.color;

    final icono = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.buttonLg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(info.icon, color: color, size: 22),
    );

    final textos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          info.tituloCorto,
          style: TextStyle(
            color: apagada ? AppColors.slate400 : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          apagada
              ? switch (situacion.tipo) {
                  ExperienciaTipo.recorrido360 => 'Este lugar todavía no cuenta con un recorrido 360°.',
                  ExperienciaTipo.arGeo => 'Por el momento este lugar no cuenta con RA por geolocalización.',
                  ExperienciaTipo.arMarcador => 'Este lugar aún no ofrece esta experiencia.',
                }
              : info.descripcion,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(height: 1.35),
        ),
        const SizedBox(height: AppSpacing.sm),
        _EstadoChip(situacion: situacion, lugar: lugar),
      ],
    );

    return Opacity(
      opacity: apagada ? 0.65 : 1,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: apagada ? AppColors.borderSubtle : color.withValues(alpha: 0.25)),
            ),
            child: compacta
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icono,
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: textos),
                      if (onTap != null) Icon(Icons.chevron_right, color: AppColors.slate500),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [icono, const SizedBox(height: AppSpacing.md), textos],
                  ),
          ),
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final ExperienciaSituacion situacion;
  final Lugar lugar;

  const _EstadoChip({required this.situacion, required this.lugar});

  @override
  Widget build(BuildContext context) {
    final (texto, icon, color) = switch (situacion.estado) {
      ExperienciaEstado.noDisponible => ('No disponible', Icons.remove_circle_outline, AppColors.slate500),
      ExperienciaEstado.disponible => ('Disponible', Icons.check_circle_outline, AppColors.emerald),
      ExperienciaEstado.bloqueada => (
          situacion.distancia == null
              ? 'Se desbloquea en el lugar'
              : 'A ${formatoDistancia(situacion.distancia!)} · acércate',
          Icons.lock_outline,
          AppColors.amber,
        ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Abre el detalle de una experiencia: hoja inferior en pantallas angostas
/// (como en el teléfono) y diálogo centrado en pantallas anchas.
Future<void> mostrarDetalleExperiencia(
  BuildContext context, {
  required Lugar lugar,
  required ExperienciaSituacion situacion,
  bool vistaPrevia = false,
  Future<void> Function()? onActivarUbicacion,
  ExperienciaSituacion Function(ExperienciaTipo tipo, Coordenadas? yo)? recalcular,
}) {
  final contenido = _DetalleExperiencia(
    lugar: lugar,
    situacion: situacion,
    vistaPrevia: vistaPrevia,
    onActivarUbicacion: onActivarUbicacion,
    recalcular: recalcular,
  );

  if (Breakpoints.isCompact(MediaQuery.of(context).size.width)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // El scrim por defecto de Flutter (`Colors.black54`) es fijo sin
      // importar el tema: en modo claro se ve como un gris muy fuerte en vez
      // de un oscurecido sutil. `AppColors.overlay` sí es theme-aware.
      barrierColor: AppColors.overlay(0.3),
      backgroundColor: AppColors.panelNavySoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.cardLg)),
      ),
      builder: (_) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: contenido,
      ),
    );
  }

  return showDialog<void>(
    context: context,
    barrierColor: AppColors.overlay(0.3),
    builder: (_) => Dialog(
      backgroundColor: AppColors.panelNavySoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.cardLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: contenido,
      ),
    ),
  );
}

class _DetalleExperiencia extends StatefulWidget {
  final Lugar lugar;
  final ExperienciaSituacion situacion;
  final bool vistaPrevia;
  final Future<void> Function()? onActivarUbicacion;
  final ExperienciaSituacion Function(ExperienciaTipo tipo, Coordenadas? yo)? recalcular;

  const _DetalleExperiencia({
    required this.lugar,
    required this.situacion,
    required this.vistaPrevia,
    this.onActivarUbicacion,
    this.recalcular,
  });

  @override
  State<_DetalleExperiencia> createState() => _DetalleExperienciaState();
}

class _DetalleExperienciaState extends State<_DetalleExperiencia> {
  late ExperienciaSituacion _situacion = widget.situacion;
  bool _buscando = false;
  bool _abriendo = false;

  ExperienciaInfo get _info => ExperienciaInfo.of(_situacion.tipo);

  Future<void> _activarUbicacion() async {
    setState(() => _buscando = true);
    await widget.onActivarUbicacion?.call();
    final yo = await UbicacionProvider.current.actual();
    if (!mounted) return;
    setState(() {
      _buscando = false;
      _situacion = widget.recalcular?.call(_situacion.tipo, yo) ??
          ExperienciaSituacion.calcular(widget.lugar, _situacion.tipo, yo);
    });
  }

  Future<void> _abrir() async {
    final launcher = ExperienciasLauncher.current;
    if (widget.vistaPrevia) {
      _aviso('Vista previa: así verá el visitante este botón.');
      return;
    }
    if (!launcher.soporta(_situacion.tipo)) {
      _aviso(_situacion.tipo == ExperienciaTipo.recorrido360
          ? 'El visor de recorridos 360° estará disponible muy pronto.'
          : 'La realidad aumentada se abre desde la app móvil de TouristMAR.');
      return;
    }
    setState(() => _abriendo = true);
    try {
      await launcher.abrir(context, widget.lugar, _situacion.tipo);
    } on ExperienciaNoConfigurada {
      _aviso('Esta experiencia estará disponible muy pronto.');
    } on ExperienciaError catch (e) {
      _aviso(e.mensaje);
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.lugar.nombre.toUpperCase(),
                        style: AppTypography.caption.copyWith(color: info.color, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(info.titulo, style: AppTypography.h2),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: AppColors.slate400),
              ),
            ],
          ),
          if (widget.vistaPrevia) ...[
            const SizedBox(height: AppSpacing.sm),
            _BannerVistaPrevia(),
          ],
          const SizedBox(height: AppSpacing.lg),
          ..._contenido(),
          const SizedBox(height: AppSpacing.xl),
          _botonPrincipal(),
        ],
      ),
    );
  }

  List<Widget> _contenido() {
    switch (_situacion.tipo) {
      case ExperienciaTipo.arMarcador:
        return [
          const ExperienciaViewport(
            tipo: ExperienciaTipo.arMarcador,
            mensaje: 'Aquí se abrirá la cámara con el contenido\nen realidad aumentada.',
          ),
          const SizedBox(height: AppSpacing.lg),
          _MarcadorReferencia(url: widget.lugar.arMarcador),
          const SizedBox(height: AppSpacing.lg),
          const _Pasos(pasos: [
            ('Busca el marcador', 'Está impreso en un cartel o placa dentro del lugar.'),
            ('Abre la cámara', 'Toca "Abrir cámara RA" y permite el acceso a la cámara.'),
            ('Apunta y explora', 'Enfoca el marcador completo; el contenido aparece encima.'),
          ]),
        ];
      case ExperienciaTipo.arGeo:
        return [
          _EstadoGeo(
            lugar: widget.lugar,
            situacion: _situacion,
            buscando: _buscando,
            onActivar: _activarUbicacion,
          ),
          const SizedBox(height: AppSpacing.lg),
          ExperienciasLauncher.current.mideDistancia(ExperienciaTipo.arGeo)
              ? const _Pasos(pasos: [
                  ('Abre la cámara', 'Toca "Iniciar RA en el lugar" y permite la cámara y tu ubicación.'),
                  ('Acércate', 'A unos ${radioVisibleDefault ~/ 1} m verás flotando en la cámara los puntos de interés y su resumen.'),
                  ('Llega al punto', 'A menos de ${radioCercanoDefault ~/ 1} m se abre la guía completa: información, fotos y audio.'),
                ])
              : const _Pasos(pasos: [
                  ('Visita el lugar', 'Esta experiencia solo existe en el sitio físico.'),
                  ('Activa tu ubicación', 'Se desbloquea al entrar en el radio marcado en el mapa.'),
                  ('Mira a tu alrededor', 'El contenido 3D aparece anclado al lugar real.'),
                ]),
        ];
      case ExperienciaTipo.recorrido360:
        return [
          _VistaPrevia360(lugar: widget.lugar),
          const SizedBox(height: AppSpacing.lg),
          const _Pasos(pasos: [
            ('Desde cualquier lugar', 'No necesitas estar en el sitio para hacer el recorrido.'),
            ('Arrastra o mueve el teléfono', 'Mira en todas direcciones; usa dos dedos para acercar.'),
          ]),
        ];
    }
  }

  Widget _botonPrincipal() {
    final tipo = _situacion.tipo;
    final bloqueada = _situacion.estado != ExperienciaEstado.disponible;
    final (label, icon) = switch (tipo) {
      ExperienciaTipo.arMarcador => ('Abrir cámara RA', Icons.photo_camera_outlined),
      ExperienciaTipo.arGeo => (bloqueada ? 'Bloqueada hasta que llegues' : 'Iniciar RA en el lugar', bloqueada ? Icons.lock_outline : Icons.view_in_ar),
      ExperienciaTipo.recorrido360 => ('Iniciar recorrido', Icons.play_arrow_rounded),
    };
    final color = _info.color;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: bloqueada || _abriendo ? null : _abrir,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: ThemeController.isDark ? AppColors.scrimDark : Colors.white,
          disabledBackgroundColor: AppColors.overlay(0.08),
          disabledForegroundColor: AppColors.slate400,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.buttonLg)),
        ),
        icon: _abriendo
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// La primera vista del recorrido ya en 360° (se puede girar) antes de
/// abrirlo completo. Si todavía carga o no hay conexión, el marco vacío.
class _VistaPrevia360 extends StatefulWidget {
  final Lugar lugar;

  const _VistaPrevia360({required this.lugar});

  @override
  State<_VistaPrevia360> createState() => _VistaPrevia360State();
}

class _VistaPrevia360State extends State<_VistaPrevia360> {
  RecorridoPublico? _recorrido;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final lista = await RecorridosService().listPublicos();
      final propio = recorridoDeLugar(lista, lugarId: widget.lugar.id, lugarNombre: widget.lugar.nombre);
      if (mounted) setState(() => _recorrido = propio);
    } catch (_) {
      // Sin conexión: se queda el marco vacío.
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _recorrido;
    if (r == null || r.escenas.isEmpty) {
      return ExperienciaViewport(
        tipo: ExperienciaTipo.recorrido360,
        mensaje: _cargando ? 'Cargando el recorrido 360°…' : 'Este lugar todavía no tiene recorrido 360°.',
      );
    }
    return ExperienciaViewport(
      tipo: ExperienciaTipo.recorrido360,
      child: Visor360(
        escenas: [for (final e in r.escenas) EscenaVisor.publica(e)],
        escenaInicialId: r.escenaInicial,
        titulo: r.titulo,
        mostrarTira: false,
      ),
    );
  }
}

class _BannerVistaPrevia extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 14, color: AppColors.amber),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Vista previa — así lo verá un visitante.',
                style: TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Imagen del marcador para que el visitante sepa qué buscar.
class _MarcadorReferencia extends StatelessWidget {
  final String? url;
  const _MarcadorReferencia({this.url});

  @override
  Widget build(BuildContext context) {
    final esImagen = url != null && url!.startsWith('http');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            clipBehavior: Clip.antiAlias,
            child: esImagen
                ? Image.network(url!, fit: BoxFit.cover)
                : const Icon(Icons.qr_code_2, size: 44, color: AppColors.scrimDark),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Busca esta imagen', style: AppTypography.h3.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text('Es el marcador que activa el contenido en realidad aumentada.', style: AppTypography.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado de desbloqueo de la RA por ubicación: distancia + mini mapa con
/// el radio.
class _EstadoGeo extends StatelessWidget {
  final Lugar lugar;
  final ExperienciaSituacion situacion;
  final bool buscando;
  final VoidCallback onActivar;

  const _EstadoGeo({required this.lugar, required this.situacion, required this.buscando, required this.onActivar});

  @override
  Widget build(BuildContext context) {
    final color = ExperienciaInfo.of(ExperienciaTipo.arGeo).color;
    final desbloqueada = situacion.estado == ExperienciaEstado.disponible;
    final d = situacion.distancia;
    final progreso = d == null ? 0.0 : (lugar.radioDesbloqueo / d).clamp(0.0, 1.0);

    final (titulo, subtitulo) = desbloqueada && d == null
        ? ('Lista para abrir', 'De lejos verás un resumen del lugar y tu distancia; al llegar se desbloquea la información completa.')
        : desbloqueada
        ? ('¡Estás aquí!', 'La experiencia está desbloqueada.')
        : d == null
            ? ('Ubicación desactivada', 'Actívala para saber qué tan cerca estás.')
            : ('Estás a ${formatoDistancia(d)}', 'Acércate a menos de ${lugar.radioDesbloqueo.round()} m para desbloquearla.');

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: (desbloqueada ? color : AppColors.amber).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: (desbloqueada ? color : AppColors.amber).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: desbloqueada ? 1 : progreso,
                      strokeWidth: 4,
                      color: desbloqueada ? color : AppColors.amber,
                      backgroundColor: AppColors.overlay(0.08),
                    ),
                    Icon(desbloqueada ? Icons.lock_open : Icons.lock_outline,
                        color: desbloqueada ? color : AppColors.amber, size: 22),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: AppTypography.h3),
                    const SizedBox(height: 2),
                    Text(subtitulo, style: AppTypography.bodySmall),
                  ],
                ),
              ),
              if (d == null && !desbloqueada)
                OutlinedButton.icon(
                  onPressed: buscando ? null : onActivar,
                  icon: buscando
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, size: 16),
                  label: const Text('Activar'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.amber),
                ),
            ],
          ),
        ),
        if (lugar.ubicacion != null) ...[
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: SizedBox(
              height: 180,
              child: MapaBase(
                centro: lugar.ubicacion!,
                zoom: 16,
                interactivo: false,
                children: [
                  capaRadio(lugar.ubicacion!, lugar.radioDesbloqueo, color),
                  capaLugares([lugar], seleccionadoId: lugar.id),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pasos extends StatelessWidget {
  final List<(String, String)> pasos;
  const _Pasos({required this.pasos});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cómo funciona', style: AppTypography.h3.copyWith(fontSize: 14)),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < pasos.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.overlay(0.08), shape: BoxShape.circle),
                  child: Text('${i + 1}',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '${pasos[i].$1}. ',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      TextSpan(text: pasos[i].$2),
                    ]),
                    style: AppTypography.body.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
