import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/lugar.dart';
import '../services/brujula.dart';
import '../services/experiencias_launcher.dart';
import '../services/ra_geo_service.dart';
import '../services/ubicacion_dispositivo.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_image.dart';

/// RA por geolocalización (Location-based AR) hecha en Flutter, sin Unity:
/// cámara de fondo + GPS + brújula sobre los puntos de interés del lugar
/// (los da de alta el admin en "Mapa y RA"; sin puntos, el pin del lugar).
/// Funciona por capas según la distancia a cada punto:
///   - lejos (fuera de `radioVisible`): guía de distancia y dirección;
///   - dentro de `radioVisible` (p. ej. 100 m): marcador flotante con título
///     y resumen, en la dirección real del punto;
///   - dentro de `radioCercano` (p. ej. 10 m): se abre la guía completa
///     (información, imagen y audio) y, si el lugar tiene marcadores de imagen,
///     el botón "Abrir RA con marcadores" pasa a la escena de marcadores de
///     Unity (ahí el GPS ya no es lo bastante preciso).
Future<void> abrirRaUbicacion(BuildContext context, Lugar lugar) {
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => RaUbicacionPage(lugar: lugar)));
}

/// Ancho que ve la cámara trasera de un teléfono, en grados (aprox.).
const _campoVision = 60.0;

/// Para salir de la capa cercana hay que alejarse estos metros de más: el
/// GPS tiembla y, sin esto, la guía se abriría y cerraría sola en el borde.
const _histeresis = 5.0;

/// Cuántos marcadores flotantes como máximo (los más cercanos).
const _maxMarcadores = 5;

/// Capa de un punto según la distancia del visitante.
enum CapaRa { lejos, visible, cerca }

class RaUbicacionPage extends StatefulWidget {
  final Lugar lugar;

  /// Solo para pruebas: posiciones, rumbos y puntos falsos, sin cámara.
  final Stream<Coordenadas>? ubicaciones;
  final Stream<double>? rumbos;
  final List<PuntoRaGeo>? puntos;
  final bool? tieneMarcadores;
  final RaGeoService? service;
  final bool usarCamara;

  const RaUbicacionPage({
    super.key,
    required this.lugar,
    this.ubicaciones,
    this.rumbos,
    this.puntos,
    this.tieneMarcadores,
    this.service,
    this.usarCamara = true,
  });

  @override
  State<RaUbicacionPage> createState() => _RaUbicacionPageState();
}

class _RaUbicacionPageState extends State<RaUbicacionPage> with WidgetsBindingObserver {
  CameraController? _camara;
  bool _sinCamara = false;

  /// Se soltó la cámara para que la use Unity (RA con marcadores); se vuelve
  /// a tomar al regresar a la app.
  bool _camaraCedida = false;
  late bool _tieneMarcadores = widget.tieneMarcadores ?? false;
  StreamSubscription<Coordenadas>? _subGps;
  StreamSubscription<double>? _subBrujula;

  List<PuntoRaGeo> _puntos = const [];
  Coordenadas? _yo;
  bool _buscandoUbicacion = true;

  /// Rumbo suavizado (la brújula tiembla mucho); null = sin brújula.
  double? _rumbo;

  /// Punto cuya guía completa está abierta (capa cercana), y los que el
  /// visitante cerró a mano (no se vuelven a abrir hasta que se aleje).
  PuntoRaGeo? _cerca;
  final Set<PuntoRaGeo> _guiasCerradas = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _puntos = widget.puntos ?? [if (widget.lugar.ubicacion != null) PuntoRaGeo.delLugar(widget.lugar)];
    if (widget.puntos == null) _cargarPuntos();
    if (widget.usarCamara) {
      _iniciarCamara();
    } else {
      _sinCamara = true;
    }
    _iniciarSensores();
  }

  /// Los puntos que dio de alta el admin. Mientras cargan (o si falla, p. ej.
  /// un lugar de ejemplo) se usa el pin del lugar.
  Future<void> _cargarPuntos() async {
    try {
      final lugar = await (widget.service ?? RaGeoService()).lugarPublico(widget.lugar.id);
      if (!mounted) return;
      setState(() {
        if (lugar.puntos.isNotEmpty) _puntos = lugar.puntos;
        _tieneMarcadores = widget.tieneMarcadores ?? lugar.tieneMarcadores;
      });
      _actualizarCapas();
    } catch (_) {}
  }

  Future<void> _iniciarCamara() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) throw StateError('sin cámara');
      final trasera = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );
      final controller = CameraController(trasera, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camara = controller);
    } catch (_) {
      if (mounted) setState(() => _sinCamara = true);
    }
  }

  void _iniciarSensores() {
    _subGps?.cancel();
    _subBrujula?.cancel();
    setState(() => _buscandoUbicacion = true);
    _subGps = (widget.ubicaciones ?? UbicacionDispositivo.seguir()).listen(
      (yo) {
        if (!mounted) return;
        setState(() {
          _yo = yo;
          _buscandoUbicacion = false;
        });
        _actualizarCapas();
      },
      onDone: () {
        if (mounted) setState(() => _buscandoUbicacion = false);
      },
      onError: (_) {
        if (mounted) setState(() => _buscandoUbicacion = false);
      },
    );
    _subBrujula = (widget.rumbos ?? Brujula.rumbo()).listen(
      (r) {
        if (!mounted) return;
        // Filtro paso bajo sobre el ángulo (sin saltar al pasar por el norte).
        setState(() => _rumbo = _rumbo == null ? r : (_rumbo! + diferenciaAngulo(r, _rumbo!) * 0.25 + 360) % 360);
      },
      onError: (_) {},
    );
  }

  /// En iPhone la brújula pide permiso con un toque.
  Future<void> _activarBrujula() async {
    await Brujula.pedirPermiso();
    _iniciarSensores();
  }

  double _distancia(PuntoRaGeo p) => distanciaMetros(_yo!, p.ubicacion);

  CapaRa _capa(PuntoRaGeo p) {
    final d = _distancia(p);
    final radioCerca = p.radioCercano + (identical(p, _cerca) ? _histeresis : 0);
    if (d <= radioCerca) return CapaRa.cerca;
    if (d <= p.radioVisible) return CapaRa.visible;
    return CapaRa.lejos;
  }

  /// Abre la guía del punto más cercano en cuya capa cercana esté el visitante
  /// y "olvida" las guías cerradas de los puntos de los que ya se alejó.
  void _actualizarCapas() {
    if (_yo == null) return;
    _guiasCerradas.removeWhere((p) => _capa(p) != CapaRa.cerca);
    final cercanos = _puntos.where((p) => _capa(p) == CapaRa.cerca).toList()
      ..sort((a, b) => _distancia(a).compareTo(_distancia(b)));
    final nuevo = cercanos.isEmpty ? null : cercanos.first;
    if (!identical(nuevo, _cerca)) setState(() => _cerca = nuevo);
  }

  void _cerrarGuia() {
    if (_cerca != null) setState(() => _guiasCerradas.add(_cerca!));
  }

  void _abrirGuia() {
    if (_cerca != null) setState(() => _guiasCerradas.remove(_cerca));
  }

  bool get _guiaAbierta => _cerca != null && !_guiasCerradas.contains(_cerca);

  /// Capa cercana → escena de marcadores de Unity. Unity corre en otra
  /// pantalla y necesita la cámara, así que primero se suelta la de aquí.
  Future<void> _abrirMarcadores() async {
    final launcher = ExperienciasLauncher.current;
    final messenger = ScaffoldMessenger.of(context);
    if (!launcher.soporta(ExperienciaTipo.arMarcador)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('La RA con marcadores se abre desde la app móvil.')),
      );
      return;
    }
    final camara = _camara;
    setState(() {
      _camara = null;
      _camaraCedida = true;
    });
    await camara?.dispose();
    if (!mounted) return;
    try {
      await launcher.abrir(context, widget.lugar, ExperienciaTipo.arMarcador);
    } on ExperienciaError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
      _recuperarCamara();
    } on ExperienciaNoConfigurada {
      messenger.showSnackBar(const SnackBar(content: Text('La RA con marcadores todavía no está disponible.')));
      _recuperarCamara();
    }
  }

  void _recuperarCamara() {
    if (!_camaraCedida || !mounted) return;
    _camaraCedida = false;
    if (widget.usarCamara) _iniciarCamara();
  }

  /// Al volver de Unity a la app, la pantalla retoma su cámara.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recuperarCamara();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subGps?.cancel();
    _subBrujula?.cancel();
    _camara?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            Positioned.fill(child: _fondo()),
            if (_yo != null && !_guiaAbierta) ..._capaRa(c.biggest),
            // Arriba con Positioned: si quedara sin posición, el Stack tomaría
            // solo la altura de esta barra y lo de abajo saldría de la pantalla.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _BotonCircular(
                          icon: Icons.close, tooltip: 'Cerrar', onTap: () => Navigator.of(context).maybePop()),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _Pildora(
                          child: Text(
                            'RA por geolocalización · ${widget.lugar.nombre}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: _guiaAbierta
                    ? ConstrainedBox(
                        // Crece con el contenido hasta 3/4 de la pantalla; lo
                        // demás se desplaza dentro de la guía.
                        constraints: BoxConstraints(maxHeight: c.biggest.height * 0.75),
                        child: _GuiaCompleta(
                          punto: _cerca!,
                          onCerrar: _cerrarGuia,
                          onMarcadores: _tieneMarcadores ? _abrirMarcadores : null,
                        ),
                      )
                    : _panel(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fondo() {
    final camara = _camara;
    if (camara != null && camara.value.isInitialized) {
      // La vista previa llena la pantalla recortando lo que sobra.
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: camara.value.previewSize?.height ?? 1080,
            height: camara.value.previewSize?.width ?? 1920,
            child: CameraPreview(camara),
          ),
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1A2E), Color(0xFF12324F)],
        ),
      ),
      alignment: Alignment.center,
      child: _sinCamara
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No se pudo abrir la cámara. Puedes seguir la dirección de los puntos igualmente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            )
          : const CircularProgressIndicator(color: Colors.white),
    );
  }

  /// Capa "visible": un marcador flotante por punto en su dirección real.
  /// Sin brújula (computadora) se apilan al centro.
  List<Widget> _capaRa(Size pantalla) {
    final visibles = _puntos.where((p) => _capa(p) != CapaRa.lejos).toList()
      ..sort((a, b) => _distancia(a).compareTo(_distancia(b)));
    final widgets = <Widget>[];
    final fuera = <(PuntoRaGeo, double)>[];
    for (final (i, p) in visibles.take(_maxMarcadores).indexed) {
      final d = _distancia(p);
      final marcador = _MarcadorFlotante(punto: p, distancia: d);
      // El más cercano abajo y más grande; los demás escalonados hacia arriba.
      final top = pantalla.height * (0.36 - i * 0.07);
      final escala = (1.15 - d / p.radioVisible * 0.35).clamp(0.75, 1.15).toDouble();
      final angulo = _rumbo == null ? null : diferenciaAngulo(rumboHacia(_yo!, p.ubicacion), _rumbo!);
      if (angulo == null) {
        widgets.add(Positioned(
            left: 0, right: 0, top: top, child: Center(child: Transform.scale(scale: escala, child: marcador))));
      } else if (angulo.abs() <= _campoVision / 2) {
        const ancho = _MarcadorFlotante.ancho;
        final x = pantalla.width * (0.5 + angulo / _campoVision);
        widgets.add(Positioned(
          left: (x - ancho / 2).clamp(8, pantalla.width - ancho - 8),
          top: top,
          width: ancho,
          child: Transform.scale(scale: escala, child: marcador),
        ));
      } else {
        fuera.add((p, angulo));
      }
    }
    // Puntos visibles que quedan fuera de la cámara: flecha hacia el más cercano.
    if (fuera.isNotEmpty && widgets.isEmpty) {
      final (p, angulo) = fuera.first;
      widgets.add(_flechaGiro(pantalla, angulo, p.titulo));
    }
    return widgets;
  }

  Widget _flechaGiro(Size pantalla, double angulo, String titulo) {
    final derecha = angulo > 0;
    return Positioned(
      top: pantalla.height * 0.4,
      left: derecha ? null : 12,
      right: derecha ? 12 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: pantalla.width - 24),
        child: _Pildora(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!derecha) const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Gira a la ${derecha ? 'derecha' : 'izquierda'} ${angulo.abs().round()}° · $titulo',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              if (derecha) const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel() {
    final color = ExperienciaInfo.of(ExperienciaTipo.arGeo).color;
    final String texto;
    Widget? accion;
    IconData icono = Icons.radar;

    if (_puntos.isEmpty) {
      texto = 'Este lugar todavía no tiene puntos de RA.';
    } else if (_yo == null) {
      texto = _buscandoUbicacion
          ? 'Buscando tu ubicación…'
          : 'Activa tu ubicación y permite el acceso para ver los puntos de interés.';
      if (!_buscandoUbicacion) {
        accion = _BotonPanel(icon: Icons.location_searching, label: 'Usar mi ubicación', onTap: _iniciarSensores);
      }
    } else if (_cerca != null) {
      // Cerró la guía a mano: puede volver a abrirla.
      icono = Icons.check_circle;
      texto = 'Estás en ${_cerca!.titulo}.';
      accion = Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _BotonPanel(icon: Icons.menu_book_outlined, label: 'Ver guía', onTap: _abrirGuia),
          if (_tieneMarcadores)
            _BotonPanel(icon: Icons.qr_code_scanner, label: 'Abrir RA con marcadores', onTap: _abrirMarcadores),
        ],
      );
    } else {
      final ordenados = [..._puntos]..sort((a, b) => _distancia(a).compareTo(_distancia(b)));
      final masCercano = ordenados.first;
      final visibles = ordenados.where((p) => _capa(p) == CapaRa.visible).length;
      final d = _distancia(masCercano);
      if (visibles > 0) {
        texto = visibles == 1
            ? 'Hay un punto de interés cerca. Apunta la cámara y acércate a menos de '
                '${masCercano.radioCercano.round()} m para abrir su guía.'
            : 'Hay $visibles puntos de interés cerca. Apunta la cámara para verlos.';
      } else {
        texto = 'El punto más cercano, ${masCercano.titulo}, está a ${formatoDistancia(d)} hacia el '
            '${_puntoCardinal(rumboHacia(_yo!, masCercano.ubicacion))}. Su marcador aparece a '
            '${masCercano.radioVisible.round()} m.';
      }
      if (_rumbo == null) {
        accion = _BotonPanel(icon: Icons.explore_outlined, label: 'Activar brújula', onTap: _activarBrujula);
      }
    }

    return _Pildora(
      radio: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, color: _cerca != null ? AppColors.emerald : color, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 13))),
            ],
          ),
          if (accion != null) ...[const SizedBox(height: AppSpacing.sm), accion],
        ],
      ),
    );
  }

  static String _puntoCardinal(double rumbo) {
    const nombres = ['norte', 'noreste', 'este', 'sureste', 'sur', 'suroeste', 'oeste', 'noroeste'];
    return nombres[((rumbo + 22.5) % 360 ~/ 45)];
  }
}

/// Capa "visible": letrero flotante del punto con su pin debajo, apuntando
/// al lugar real.
class _MarcadorFlotante extends StatelessWidget {
  static const ancho = 220.0;

  final PuntoRaGeo punto;
  final double distancia;

  const _MarcadorFlotante({required this.punto, required this.distancia});

  @override
  Widget build(BuildContext context) {
    final color = ExperienciaInfo.of(ExperienciaTipo.arGeo).color;
    return SizedBox(
      width: ancho,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color, width: 2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatoDistancia(distancia),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 2),
                Text(punto.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                if (punto.resumen.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(punto.resumen,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ],
            ),
          ),
          Container(width: 3, height: 28, color: color),
          Icon(Icons.location_on, color: color, size: 30),
        ],
      ),
    );
  }
}

/// Capa "cercana": la guía completa del punto (información, imagen y audio).
class _GuiaCompleta extends StatefulWidget {
  final PuntoRaGeo punto;
  final VoidCallback onCerrar;

  /// null = el lugar no tiene marcadores de imagen.
  final VoidCallback? onMarcadores;

  const _GuiaCompleta({required this.punto, required this.onCerrar, this.onMarcadores});

  @override
  State<_GuiaCompleta> createState() => _GuiaCompletaState();
}

class _GuiaCompletaState extends State<_GuiaCompleta> {
  AudioPlayer? _audio;
  bool _reproduciendo = false;
  StreamSubscription<PlayerState>? _sub;

  @override
  void didUpdateWidget(_GuiaCompleta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.punto, widget.punto)) _pararAudio();
  }

  Future<void> _alternarAudio() async {
    final audio = _audio ??= AudioPlayer();
    _sub ??= audio.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _reproduciendo = s == PlayerState.playing);
    });
    try {
      if (_reproduciendo) {
        await audio.pause();
      } else {
        await audio.play(UrlSource(widget.punto.audioUrl));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No se pudo reproducir la guía de audio.')));
      }
    }
  }

  void _pararAudio() {
    _audio?.stop();
    if (mounted) setState(() => _reproduciendo = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _audio?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.punto;
    final color = AppColors.emerald;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF20B1A2E),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.imagenUrl.isNotEmpty) SizedBox(height: 160, child: CoverImage(source: p.imagenUrl)),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: color, size: 18),
                      const SizedBox(width: 6),
                      Text('¡Llegaste!', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(p.titulo,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  if (p.resumen.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(p.resumen, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                  if (widget.onMarcadores != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.brandTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        border: Border.all(color: AppColors.brandTeal.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Aquí hay marcadores de realidad aumentada: apunta la cámara a las imágenes del lugar.',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          FilledButton.icon(
                            onPressed: () {
                              _pararAudio();
                              widget.onMarcadores!();
                            },
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: const Text('Abrir RA con marcadores', style: TextStyle(fontWeight: FontWeight.w700)),
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brandTeal, foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (p.audioUrl.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: _alternarAudio,
                      icon: Icon(_reproduciendo ? Icons.pause : Icons.headphones, size: 18),
                      label: Text(_reproduciendo ? 'Pausar guía de audio' : 'Escuchar guía de audio'),
                      style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                    ),
                  ],
                  if (p.detalle.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(p.detalle, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45)),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: OutlinedButton.icon(
              onPressed: () {
                _pararAudio();
                widget.onCerrar();
              },
              icon: const Icon(Icons.photo_camera_outlined, size: 16),
              label: const Text('Volver a la cámara'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonPanel extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BotonPanel({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
    );
  }
}

class _Pildora extends StatelessWidget {
  final Widget child;
  final double radio;
  final EdgeInsets padding;

  const _Pildora(
      {required this.child, this.radio = 999, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration:
          BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(radio)),
      child: child,
    );
  }
}

class _BotonCircular extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _BotonCircular({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 42, height: 42, child: Icon(icon, color: Colors.white, size: 20)),
        ),
      ),
    );
  }
}
