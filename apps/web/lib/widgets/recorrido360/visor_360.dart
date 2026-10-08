import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:panorama_viewer/panorama_viewer.dart';

import '../../services/recorridos_service.dart';
import '../../theme/app_theme.dart';

/// Flecha de un escenario hacia otro. Ángulos en grados con la misma
/// convención que el backend: [yaw] -180…180, 0 = centro horizontal
/// de la foto equirectangular y positivo hacia la derecha
/// (`yaw = (u − 0.5) · 360`, con u = x / ancho de la imagen); [pitch] -90…90,
/// 0 = horizonte y negativo hacia el piso.
class EnlaceVisor {
  final String destinoId;
  final double yaw;
  final double pitch;
  final String etiqueta;

  const EnlaceVisor({required this.destinoId, required this.yaw, this.pitch = 0, this.etiqueta = ''});
}

/// Un escenario tal como lo pinta [Visor360], venga de la API pública (turista)
/// o del panel de administración.
class EscenaVisor {
  final String id;
  final String titulo;
  final String descripcion;
  final String urlImagen;
  final String urlMiniatura;
  final double yawInicial;
  final List<EnlaceVisor> enlaces;

  const EscenaVisor({
    required this.id,
    required this.titulo,
    this.descripcion = '',
    required this.urlImagen,
    this.urlMiniatura = '',
    this.yawInicial = 0,
    this.enlaces = const [],
  });

  factory EscenaVisor.publica(EscenaPublica e) => EscenaVisor(
        id: e.id,
        titulo: e.titulo,
        descripcion: e.descripcion,
        urlImagen: e.urlImagen,
        urlMiniatura: e.urlMiniatura,
        yawInicial: e.yawInicial,
        enlaces: [
          for (final l in e.enlaces) EnlaceVisor(destinoId: l.destino, yaw: l.yaw, pitch: l.pitch, etiqueta: l.etiqueta),
        ],
      );

  /// Del panel: las flechas apuntan por casilla, aquí por id.
  static List<EscenaVisor> deRecorridoAdmin(Recorrido360 r) {
    final idPorPosicion = {for (final e in r.escenas) e.posicion: e.id};
    return [
      for (final e in r.escenas)
        EscenaVisor(
          id: e.id,
          titulo: e.nombre,
          descripcion: e.descripcion,
          urlImagen: e.imagenUrl,
          urlMiniatura: e.miniaturaUrl,
          yawInicial: e.yawInicial,
          enlaces: [
            for (final l in e.enlaces)
              if (idPorPosicion[l.destino] != null)
                EnlaceVisor(destinoId: idPorPosicion[l.destino]!, yaw: l.yaw, pitch: l.pitch, etiqueta: l.etiqueta),
          ],
        ),
    ];
  }
}

/// Mueve la cámara del visor desde fuera (p. ej. "volver a la vista inicial").
class Visor360Controller {
  _Visor360State? _state;

  /// Hacia dónde mira la cámara ahora mismo (grados).
  double get yaw => _state?._yaw ?? 0;
  double get pitch => _state?._pitch ?? 0;

  void mirarA(double yaw, [double pitch = 0]) => _state?._pano.setView(pitch, yaw);
}

/// Visor de recorridos 360° al estilo Street View: la foto del escenario
/// envuelta en una esfera, flechas para pasar al siguiente escenario, el
/// nombre del lugar arriba y la tira de escenarios abajo.
///
/// Es el mismo visor para el turista (web y móvil) y para la vista previa del
/// panel de administración.
class Visor360 extends StatefulWidget {
  final List<EscenaVisor> escenas;
  final String? escenaInicialId;

  /// Escenario a mostrar si el padre controla la navegación (el panel lo
  /// usa para seleccionar desde la cuadrícula). null = lo maneja el visor.
  final String? escenaId;
  final ValueChanged<String>? onEscenaCambiada;

  final String? titulo;
  final String? subtitulo;
  final VoidCallback? onCerrar;
  /// null = el azul de los recorridos 360° (`AppColors.oceanBlue`).
  final Color? acento;
  final bool mostrarTira;
  final bool usarGiroscopio;

  /// Edición (panel admin): con [onTapPanorama] cada toque en la foto
  /// devuelve su yaw/pitch, y con [onFlechaTocada] las flechas se editan en
  /// lugar de navegar.
  final void Function(double yaw, double pitch)? onTapPanorama;
  final ValueChanged<EnlaceVisor>? onFlechaTocada;

  final Visor360Controller? controller;

  /// Botones extra arriba a la derecha (p. ej. pantalla completa).
  final List<Widget> acciones;

  const Visor360({
    super.key,
    required this.escenas,
    this.escenaInicialId,
    this.escenaId,
    this.onEscenaCambiada,
    this.titulo,
    this.subtitulo,
    this.onCerrar,
    this.acento,
    this.mostrarTira = true,
    this.usarGiroscopio = false,
    this.onTapPanorama,
    this.onFlechaTocada,
    this.controller,
    this.acciones = const [],
  });

  @override
  State<Visor360> createState() => _Visor360State();
}

class _Visor360State extends State<Visor360> {
  final _pano = PanoramaController();
  late String? _propioId = widget.escenaInicialId;
  String? _cargadaId;
  double _yaw = 0;
  double _pitch = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(Visor360 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _pano.dispose();
    super.dispose();
  }

  EscenaVisor? get _actual {
    final id = widget.escenaId ?? _propioId;
    for (final e in widget.escenas) {
      if (e.id == id) return e;
    }
    return widget.escenas.isEmpty ? null : widget.escenas.first;
  }

  void _ir(String id) {
    if (widget.escenaId == null) setState(() => _propioId = id);
    widget.onEscenaCambiada?.call(id);
  }

  String _tituloDe(String id) {
    for (final e in widget.escenas) {
      if (e.id == id) return e.titulo;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final escena = _actual;
    if (escena == null) {
      return const ColoredBox(
        color: AppColors.scrimDark,
        child: Center(child: Text('Este recorrido todavía no tiene escenarios.', style: TextStyle(color: Colors.white70))),
      );
    }
    final indice = widget.escenas.indexOf(escena);
    final editando = widget.onFlechaTocada != null;
    final acento = widget.acento ?? AppColors.oceanBlue;

    return ColoredBox(
      color: AppColors.scrimDark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PanoramaViewer(
            // Una vista nueva por escenario: así arranca en su vista inicial.
            key: ValueKey('${escena.id}|${escena.urlImagen}'),
            longitude: escena.yawInicial,
            // Las fotos de 1280×640 se ven borrosas con más acercamiento.
            maxZoom: 2.5,
            sensorControl: widget.usarGiroscopio ? SensorControl.orientation : SensorControl.none,
            panoramaController: _pano,
            onImageLoad: () {
              if (mounted) setState(() => _cargadaId = escena.id);
            },
            onViewChanged: (lon, lat, _) {
              _yaw = lon;
              _pitch = lat;
            },
            onTap: widget.onTapPanorama == null ? null : (lon, lat, _) => widget.onTapPanorama!(lon, lat),
            hotspots: [
              for (final enlace in escena.enlaces)
                Hotspot(
                  longitude: enlace.yaw,
                  latitude: enlace.pitch,
                  width: 150,
                  height: 92,
                  widget: _Flecha(
                    etiqueta: enlace.etiqueta.isNotEmpty ? enlace.etiqueta : _tituloDe(enlace.destinoId),
                    acento: acento,
                    editando: editando,
                    onTap: () => editando ? widget.onFlechaTocada!(enlace) : _ir(enlace.destinoId),
                  ),
                ),
            ],
            child: Image(image: TexturaSuave360(escena.urlImagen)),
          ),
          if (_cargadaId != escena.id)
            IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (escena.urlMiniatura.isNotEmpty)
                    Opacity(opacity: 0.35, child: Image.network(escena.urlMiniatura, fit: BoxFit.cover)),
                  Center(child: CircularProgressIndicator(color: acento)),
                ],
              ),
            ),
          Positioned(
            left: AppSpacing.md,
            top: AppSpacing.md,
            right: AppSpacing.md,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: _Cristal(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onCerrar != null) ...[
                          _BotonRedondo(icon: Icons.arrow_back, tooltip: 'Salir del recorrido', onTap: widget.onCerrar!),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.titulo != null)
                                Text(widget.titulo!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                              Text(
                                '${escena.titulo} · ${indice + 1} de ${widget.escenas.length}'
                                '${widget.subtitulo == null ? '' : ' · ${widget.subtitulo}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _Cristal(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BotonRedondo(
                        icon: Icons.threed_rotation,
                        tooltip: 'Volver a la vista inicial',
                        onTap: () => _pano.setView(0, escena.yawInicial),
                      ),
                      ...widget.acciones,
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (escena.descripcion.isNotEmpty)
            Positioned(
              left: AppSpacing.md,
              bottom: widget.mostrarTira && widget.escenas.length > 1 ? 104 : AppSpacing.md,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: _Cristal(
                  child: Text(escena.descripcion, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35)),
                ),
              ),
            ),
          if (widget.mostrarTira && widget.escenas.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Tira(escenas: widget.escenas, actualId: escena.id, acento: acento, onTap: _ir),
            ),
        ],
      ),
    );
  }
}

/// Flecha para pasar a otro escenario: círculo blanco con la flecha y el
/// nombre del destino debajo.
class _Flecha extends StatelessWidget {
  final String etiqueta;
  final Color acento;
  final bool editando;
  final VoidCallback onTap;

  const _Flecha({required this.etiqueta, required this.acento, required this.editando, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  border: Border.all(color: acento, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 3))],
                ),
                child: Icon(editando ? Icons.edit_location_alt_outlined : Icons.arrow_upward_rounded, color: acento, size: 26),
              ),
              const SizedBox(height: 6),
              if (etiqueta.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tira extends StatelessWidget {
  final List<EscenaVisor> escenas;
  final String actualId;
  final Color acento;
  final ValueChanged<String> onTap;

  const _Tira({required this.escenas, required this.actualId, required this.acento, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 16, AppSpacing.md, AppSpacing.md),
        itemCount: escenas.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final e = escenas[i];
          final actual = e.id == actualId;
          return Tooltip(
            message: e.titulo,
            child: GestureDetector(
              onTap: () => onTap(e.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 112,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: actual ? acento : Colors.white24, width: actual ? 2.5 : 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    e.urlMiniatura.isEmpty
                        ? const ColoredBox(color: Colors.white10)
                        : Image.network(e.urlMiniatura, fit: BoxFit.cover),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          '${i + 1}. ${e.titulo}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Cristal extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _Cristal({required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.buttonLg),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}

/// Botón circular claro sobre la foto (mismo estilo en todos los controles
/// del visor).
class VisorBoton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const VisorBoton({super.key, required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => _BotonRedondo(icon: icon, tooltip: tooltip, onTap: onTap);
}

class _BotonRedondo extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _BotonRedondo({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: Colors.white, size: 20)),
        ),
      ),
    );
  }
}

/// La foto del escenario lista para la esfera. `flutter_cube` (lo que usa
/// `panorama_viewer`) pinta la textura sin filtrar, al píxel más cercano, y
/// una foto de 1280×640 se ve en bloques al estirarse en pantalla. Aquí se
/// redibuja una sola vez a [ancho]×[ancho]/2 con filtrado suave, así lo que
/// se estira ya son píxeles interpolados. 3072×1536 RGBA ≈ 18 MB por
/// escenario; las fotos que ya son así de grandes se dejan tal cual.
@immutable
class TexturaSuave360 extends ImageProvider<TexturaSuave360> {
  final String url;
  final int ancho;

  const TexturaSuave360(this.url, {this.ancho = 3072});

  @override
  Future<TexturaSuave360> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(TexturaSuave360 key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_cargar(), informationCollector: () => [DiagnosticsProperty('url', url)]);

  Future<ImageInfo> _cargar() async {
    final original = Completer<ui.Image>();
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    late final ImageStreamListener escucha;
    escucha = ImageStreamListener(
      (info, _) {
        if (!original.isCompleted) original.complete(info.image.clone());
        stream.removeListener(escucha);
      },
      onError: (error, stack) {
        if (!original.isCompleted) original.completeError(error, stack);
        stream.removeListener(escucha);
      },
    );
    stream.addListener(escucha);
    final src = await original.future;
    if (src.width >= ancho) return ImageInfo(image: src);

    final alto = ancho ~/ 2;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      src,
      Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      Rect.fromLTWH(0, 0, ancho.toDouble(), alto.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final grande = await picture.toImage(ancho, alto);
    picture.dispose();
    src.dispose();
    return ImageInfo(image: grande);
  }

  @override
  bool operator ==(Object other) => other is TexturaSuave360 && other.url == url && other.ancho == ancho;

  @override
  int get hashCode => Object.hash(url, ancho);
}
