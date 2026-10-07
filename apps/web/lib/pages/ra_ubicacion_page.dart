import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/lugar.dart';
import '../services/brujula.dart';
import '../services/experiencias_launcher.dart';
import '../services/ubicacion_dispositivo.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_image.dart';

/// RA por ubicación hecha en Flutter, sin Unity: con la cámara de fondo,
/// el GPS y la brújula muestra flotando dónde está el pin del lugar (su
/// nombre y a cuántos metros), o una flecha para girar hacia él. Funciona
/// con el pin que el negocio o el admin marcaron en el mapa: no hay que dar
/// nada de alta en Unity. Al entrar al radio del lugar la tarjeta cambia a
/// "¡Llegaste!".
Future<void> abrirRaUbicacion(BuildContext context, Lugar lugar) {
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => RaUbicacionPage(lugar: lugar)));
}

/// Ancho que ve la cámara trasera de un teléfono, en grados (aprox.).
const _campoVision = 60.0;

class RaUbicacionPage extends StatefulWidget {
  final Lugar lugar;

  /// Solo para pruebas: posiciones y rumbos falsos, sin cámara.
  final Stream<Coordenadas>? ubicaciones;
  final Stream<double>? rumbos;
  final bool usarCamara;

  const RaUbicacionPage({super.key, required this.lugar, this.ubicaciones, this.rumbos, this.usarCamara = true});

  @override
  State<RaUbicacionPage> createState() => _RaUbicacionPageState();
}

class _RaUbicacionPageState extends State<RaUbicacionPage> {
  CameraController? _camara;
  bool _sinCamara = false;
  StreamSubscription<Coordenadas>? _subGps;
  StreamSubscription<double>? _subBrujula;

  Coordenadas? _yo;
  bool _buscandoUbicacion = true;
  /// Rumbo suavizado (la brújula tiembla mucho); null = sin brújula.
  double? _rumbo;

  Coordenadas get _destino => widget.lugar.ubicacion!;

  @override
  void initState() {
    super.initState();
    if (widget.usarCamara) {
      _iniciarCamara();
    } else {
      _sinCamara = true;
    }
    _iniciarSensores();
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
        if (mounted) {
          setState(() {
            _yo = yo;
            _buscandoUbicacion = false;
          });
        }
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

  @override
  void dispose() {
    _subGps?.cancel();
    _subBrujula?.cancel();
    _camara?.dispose();
    super.dispose();
  }

  double? get _distancia => _yo == null ? null : distanciaMetros(_yo!, _destino);

  bool get _enZona => _distancia != null && _distancia! <= widget.lugar.radioDesbloqueo;

  /// Ángulo del lugar respecto a donde apunta el teléfono (-180…180).
  double? get _angulo => _yo == null || _rumbo == null ? null : diferenciaAngulo(rumboHacia(_yo!, _destino), _rumbo!);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            Positioned.fill(child: _fondo()),
            if (_yo != null) ..._capaRa(c.biggest),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _BotonCircular(icon: Icons.close, tooltip: 'Cerrar', onTap: () => Navigator.of(context).maybePop()),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _Pildora(
                        child: Text(
                          'RA por ubicación · ${widget.lugar.nombre}',
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
            Positioned(left: 12, right: 12, bottom: 12, child: SafeArea(top: false, child: _panel())),
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
                'No se pudo abrir la cámara. Puedes seguir la dirección del lugar igualmente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            )
          : const CircularProgressIndicator(color: Colors.white),
    );
  }

  /// La tarjeta flotante sobre el lugar o la flecha para girar hacia él.
  List<Widget> _capaRa(Size pantalla) {
    final angulo = _angulo;
    final tarjeta = _TarjetaLugar(lugar: widget.lugar, distancia: _distancia!, enZona: _enZona);

    // Sin brújula (computadora) o dentro de la zona: la tarjeta al centro.
    if (angulo == null || _enZona) {
      return [
        Positioned(
          left: 0,
          right: 0,
          top: pantalla.height * 0.22,
          child: Center(child: tarjeta),
        ),
      ];
    }
    if (angulo.abs() <= _campoVision / 2) {
      // Más cerca = más grande, como un letrero real.
      final escala = (1.25 - (_distancia! / 2000)).clamp(0.8, 1.2);
      final x = pantalla.width * (0.5 + angulo / _campoVision);
      const ancho = 240.0;
      return [
        Positioned(
          left: (x - ancho / 2).clamp(8, pantalla.width - ancho - 8),
          top: pantalla.height * 0.22,
          width: ancho,
          child: Transform.scale(scale: escala.toDouble(), child: tarjeta),
        ),
      ];
    }
    final derecha = angulo > 0;
    return [
      Positioned(
        top: pantalla.height * 0.4,
        left: derecha ? null : 12,
        right: derecha ? 12 : null,
        child: _Pildora(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!derecha) const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                'Gira a la ${derecha ? 'derecha' : 'izquierda'} ${angulo.abs().round()}°',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              if (derecha) const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _panel() {
    final color = ExperienciaInfo.of(ExperienciaTipo.arGeo).color;
    final d = _distancia;
    final String texto;
    if (d == null) {
      texto = _buscandoUbicacion
          ? 'Buscando tu ubicación…'
          : 'Activa tu ubicación y permite el acceso para ver dónde está el lugar.';
    } else if (_enZona) {
      texto = '¡Estás en ${widget.lugar.nombre}!';
    } else if (_rumbo == null) {
      texto = 'A ${formatoDistancia(d)}, hacia el ${_puntoCardinal(rumboHacia(_yo!, _destino))}. '
          'Tu dispositivo no reporta brújula: camina en esa dirección.';
    } else {
      texto = 'A ${formatoDistancia(d)}. Apunta la cámara hacia el lugar; '
          'la zona de RA empieza a ${widget.lugar.radioDesbloqueo.round()} m.';
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
              Icon(_enZona ? Icons.check_circle : Icons.radar, color: _enZona ? AppColors.emerald : color, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 13))),
            ],
          ),
          if (d == null && !_buscandoUbicacion) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _iniciarSensores,
              icon: const Icon(Icons.location_searching, size: 16),
              label: const Text('Usar mi ubicación'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
            ),
          ] else if (d != null && _rumbo == null && !_enZona) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _activarBrujula,
              icon: const Icon(Icons.explore_outlined, size: 16),
              label: const Text('Activar brújula'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
            ),
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

/// Letrero flotante del lugar con su pin debajo, apuntando al punto real.
class _TarjetaLugar extends StatelessWidget {
  final Lugar lugar;
  final double distancia;
  final bool enZona;

  const _TarjetaLugar({required this.lugar, required this.distancia, required this.enZona});

  @override
  Widget build(BuildContext context) {
    final color = enZona ? AppColors.emerald : ExperienciaInfo.of(ExperienciaTipo.arGeo).color;
    return SizedBox(
      width: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 18)],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 90, child: CoverImage(source: lugar.portada)),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enZona ? '¡Llegaste!' : formatoDistancia(distancia),
                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(lugar.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                      if (lugar.categoriaTexto.isNotEmpty)
                        Text(lugar.categoriaTexto, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      if (enZona && lugar.descripcion.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(lugar.descripcion,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(width: 3, height: 36, color: color),
          Icon(Icons.location_on, color: color, size: 34),
        ],
      ),
    );
  }
}

class _Pildora extends StatelessWidget {
  final Widget child;
  final double radio;
  final EdgeInsets padding;

  const _Pildora({required this.child, this.radio = 999, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(radio)),
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
