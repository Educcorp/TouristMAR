import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/lugar.dart';
import '../services/brujula.dart';
import '../services/experiencias_launcher.dart';
import '../services/ra_geo_service.dart';
import '../services/ubicacion_dispositivo.dart';
import '../widgets/cover_image.dart';
import '../widgets/aviso.dart';
import '../widgets/ra/vidrio_ra.dart';

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
        aviso('La RA con marcadores se abre desde la app móvil.'),
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
      messenger.showSnackBar(aviso(e.mensaje, tipo: AvisoTipo.error));
      _recuperarCamara();
    } on ExperienciaNoConfigurada {
      messenger.showSnackBar(aviso('La RA con marcadores todavía no está disponible.'));
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
                      BotonCircularRa(
                          icon: Icons.close, tooltip: 'Cerrar', onTap: () => Navigator.of(context).maybePop()),
                      const SizedBox(width: 10),
                      Flexible(
                        child: _Pildora(
                          child: Text(
                            _yo == null || _guiaAbierta ? 'RA por geolocalización' : 'Mira a tu alrededor con la cámara',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5),
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
                          distancia: _distancia(_cerca!),
                          categoria: widget.lugar.categoriaVisible,
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
          colors: [Color(0xFF0B2A3A), Color(0xFF123F52)],
        ),
      ),
      alignment: Alignment.center,
      child: _sinCamara
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No se pudo abrir la cámara. Puedes seguir la dirección de los puntos igualmente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
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

  /// Tarjeta de vidrio de abajo (diseño de la tarjeta de Unity,
  /// ControladorPlayas + VisorLiquidGlass): chip de estado, categoría, nombre
  /// del lugar, qué hacer, y la acción como botón píldora.
  Widget _panel() {
    final String texto;
    String? chip;
    var colorChip = RaEstilo.lejos;
    var latido = false;
    final acciones = <Widget>[];

    if (_puntos.isEmpty) {
      texto = 'Este lugar todavía no tiene puntos de RA.';
    } else if (_yo == null) {
      chip = _buscandoUbicacion ? 'Obteniendo ubicación…' : 'Sin ubicación';
      colorChip = _buscandoUbicacion ? Colors.white : RaEstilo.lejos;
      latido = _buscandoUbicacion;
      texto = _buscandoUbicacion
          ? 'Buscando tu ubicación…'
          : 'Activa tu ubicación y permite el acceso para ver los puntos de interés.';
      if (!_buscandoUbicacion) {
        acciones.add(BotonPildoraRa(
            icon: Icons.location_searching, label: 'Usar mi ubicación', onTap: _iniciarSensores, activo: true));
      }
    } else if (_cerca != null) {
      // Cerró la guía a mano: puede volver a abrirla.
      chip = 'Estás aquí';
      colorChip = RaEstilo.acento;
      latido = true;
      texto = 'Estás en ${_cerca!.titulo}.';
      acciones.add(BotonPildoraRa(icon: Icons.menu_book_outlined, label: 'Ver guía', onTap: _abrirGuia, activo: true));
      if (_tieneMarcadores) {
        acciones.add(
            BotonPildoraRa(icon: Icons.qr_code_scanner, label: 'Abrir RA con marcadores', onTap: _abrirMarcadores));
      }
    } else {
      final ordenados = [..._puntos]..sort((a, b) => _distancia(a).compareTo(_distancia(b)));
      final masCercano = ordenados.first;
      final visibles = ordenados.where((p) => _capa(p) == CapaRa.visible).length;
      final d = _distancia(masCercano);
      if (visibles > 0) {
        chip = 'Cerca · ${formatoDistancia(d)}';
        colorChip = RaEstilo.acento;
        texto = visibles == 1
            ? 'Hay un punto de interés cerca. Apunta la cámara y acércate a menos de '
                '${masCercano.radioCercano.round()} m para abrir su guía.'
            : 'Hay $visibles puntos de interés cerca. Apunta la cámara para verlos.';
      } else {
        chip = 'A ${formatoDistancia(d)} de ti';
        texto = 'El punto más cercano, ${masCercano.titulo}, está a ${formatoDistancia(d)} hacia el '
            '${_puntoCardinal(rumboHacia(_yo!, masCercano.ubicacion))}. Su marcador aparece a '
            '${masCercano.radioVisible.round()} m.';
      }
      acciones.add(_rumbo == null
          ? BotonPildoraRa(icon: Icons.explore_outlined, label: 'Activar brújula', onTap: _activarBrujula)
          : const BotonPildoraRa(label: 'Acércate para ver más'));
    }

    return VidrioRa(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chip != null) ...[
            ChipEstadoRa(texto: chip, color: colorChip, latido: latido),
            const SizedBox(height: 14),
          ],
          CategoriaRa(widget.lugar.categoriaVisible),
          const SizedBox(height: 6),
          TituloRa(widget.lugar.nombre, maxLineas: 2, tamano: 24),
          const SizedBox(height: 10),
          Text(texto, style: const TextStyle(color: RaEstilo.cuerpo, fontSize: 15, height: 1.3)),
          if (acciones.isNotEmpty) ...[
            const SizedBox(height: 18),
            const DivisorRa(),
            const SizedBox(height: 16),
            for (final (i, a) in acciones.indexed) ...[if (i > 0) const SizedBox(height: 10), a],
          ],
        ],
      ),
    );
  }

  static String _puntoCardinal(double rumbo) {
    const nombres = ['norte', 'noreste', 'este', 'sureste', 'sur', 'suroeste', 'oeste', 'noroeste'];
    return nombres[((rumbo + 22.5) % 360 ~/ 45)];
  }
}

/// Capa "visible": letrero de vidrio del punto (distancia, título y resumen)
/// con su pin debajo, apuntando al lugar real.
class _MarcadorFlotante extends StatelessWidget {
  static const ancho = 232.0;

  final PuntoRaGeo punto;
  final double distancia;

  const _MarcadorFlotante({required this.punto, required this.distancia});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VidrioRa(
            radio: 24,
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ChipEstadoRa(texto: formatoDistancia(distancia), color: RaEstilo.acento),
                const SizedBox(height: 9),
                TituloRa(punto.titulo, maxLineas: 2, tamano: 17),
                if (punto.resumen.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(punto.resumen,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: RaEstilo.cuerpo, fontSize: 13, height: 1.3)),
                ],
              ],
            ),
          ),
          // Tallo que se desvanece hacia el pin
          Container(
            width: 2,
            height: 30,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x73FFFFFF), RaEstilo.acento],
              ),
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: RaEstilo.acento,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [BoxShadow(color: RaEstilo.acento.withValues(alpha: 0.6), blurRadius: 14)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Capa "cercana": la guía completa del punto, en la tarjeta de vidrio:
/// "Estás aquí", categoría, título, resumen, la información detallada del lugar ([PuntoRaGeo.detalle],
/// sale de la ficha del lugar), imagen y audio.
class _GuiaCompleta extends StatefulWidget {
  final PuntoRaGeo punto;
  final double distancia;
  final String categoria;
  final VoidCallback onCerrar;

  /// null = el lugar no tiene marcadores de imagen.
  final VoidCallback? onMarcadores;

  const _GuiaCompleta({
    required this.punto,
    required this.distancia,
    required this.categoria,
    required this.onCerrar,
    this.onMarcadores,
  });

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
            .showSnackBar(aviso('No se pudo reproducir la guía de audio.'));
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
    return VidrioRa(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChipEstadoRa(
                    texto: 'Estás aquí · ${formatoDistancia(widget.distancia)}',
                    color: RaEstilo.acento,
                    latido: true,
                  ),
                  const SizedBox(height: 14),
                  if (widget.categoria.trim().isNotEmpty) ...[
                    CategoriaRa(widget.categoria),
                    const SizedBox(height: 6),
                  ],
                  TituloRa(p.titulo),
                  if (p.resumen.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(p.resumen, style: const TextStyle(color: RaEstilo.cuerpo, fontSize: 15, height: 1.3)),
                  ],
                  if (p.imagenUrl.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(height: 150, width: double.infinity, child: CoverImage(source: p.imagenUrl)),
                    ),
                  ],
                  if (p.audioUrl.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    BotonPildoraRa(
                      icon: _reproduciendo ? Icons.pause : Icons.headphones,
                      label: _reproduciendo ? 'Pausar guía de audio' : 'Escuchar guía de audio',
                      onTap: _alternarAudio,
                    ),
                  ],
                  if (p.detalle.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'INFORMACIÓN DEL LUGAR',
                      style: TextStyle(
                          color: RaEstilo.secundario, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6),
                    ),
                    const SizedBox(height: 6),
                    Text(p.detalle, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 15, height: 1.5)),
                  ],
                  if (widget.onMarcadores != null) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Aquí hay marcadores de realidad aumentada: apunta la cámara a las imágenes del lugar.',
                      style: TextStyle(color: RaEstilo.cuerpo, fontSize: 14, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    BotonPildoraRa(
                      icon: Icons.qr_code_scanner,
                      label: 'Abrir RA con marcadores',
                      onTap: () {
                        _pararAudio();
                        widget.onMarcadores!();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DivisorRa(),
                const SizedBox(height: 16),
                BotonPildoraRa(
                  icon: Icons.photo_camera_outlined,
                  label: 'Volver a la cámara',
                  activo: true,
                  onTap: () {
                    _pararAudio();
                    widget.onCerrar();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Píldora de vidrio (instrucción de arriba, "Gira a la derecha…").
class _Pildora extends StatelessWidget {
  final Widget child;

  const _Pildora({required this.child});

  @override
  Widget build(BuildContext context) {
    return VidrioRa(
      radio: 23,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: child,
    );
  }
}
