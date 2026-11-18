import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/services/auth_service.dart' show apiUrl;

/// Un marcador del lugar, ya con el número ArUco que trae impreso.
class MarcadorAruco {
  final int id;

  /// Diccionario ArUco ("4x4", "6x6"…); null si el número salió del nombre.
  final String? diccionario;
  final String nombre;
  final String titulo;
  final String texto;

  const MarcadorAruco({
    required this.id,
    required this.diccionario,
    required this.nombre,
    required this.titulo,
    required this.texto,
  });
}

/// Un diccionario de ArUco con su detector.
class _Diccionario {
  final String nombre;
  final cv.ArucoDetector detector;

  _Diccionario(this.nombre, cv.PredefinedDictionaryType tipo)
      : detector = cv.ArucoDetector.create(cv.ArucoDictionary.predefined(tipo), cv.ArucoDetectorParameters.empty());
}

/// Lo que se ve ahora mismo en la cámara.
class _Deteccion {
  final String diccionario;
  final int id;

  /// Esquinas del marcador en la vista previa (0..1, vertical).
  final List<Offset> esquinas;
  final DateTime vista;

  _Deteccion(this.diccionario, this.id, this.esquinas, this.vista);
}

/// RA con marcadores **ArUco** (los de https://chev.me/arucogen/, de
/// cualquier tamaño: 4x4, 5x5, 6x6, 7x7 u "Original ArUco").
///
/// ARCore (lo que usaba Unity) no reconoce los ArUco: tienen muy pocos
/// "puntos de detalle" para su algoritmo de imágenes. Aquí los detecta OpenCV
/// (paquete opencv_dart) sobre la cámara y se muestra la información del
/// marcador encima.
///
/// Los marcadores salen del endpoint público de siempre:
/// GET /api/marcadores?negocioId={lugarId} → {nombre, urlImagen, textoParaMostrar}.
/// Para saber qué número ArUco es cada uno, se lee la imagen que subió el
/// admin (el mismo ArUco); si no se puede, el número que traiga el nombre
/// (p. ej. "aruco-3" o "fime 7").
class ArucoPage extends StatefulWidget {
  final Lugar lugar;

  const ArucoPage({super.key, required this.lugar});

  @override
  State<ArucoPage> createState() => _ArucoPageState();
}

class _ArucoPageState extends State<ArucoPage> with SingleTickerProviderStateMixin {
  /// Los diccionarios de chev.me. En cada tamaño, los IDs bajos son iguales en
  /// las versiones _50/_100/_250/_1000, así que con la de 1000 se leen todos.
  /// El mismo número (p. ej. 0) es un marcador distinto en cada tamaño.
  late final List<_Diccionario> _diccionarios = [
    _Diccionario('4x4', cv.PredefinedDictionaryType.DICT_4X4_1000),
    _Diccionario('5x5', cv.PredefinedDictionaryType.DICT_5X5_1000),
    _Diccionario('6x6', cv.PredefinedDictionaryType.DICT_6X6_1000),
    _Diccionario('7x7', cv.PredefinedDictionaryType.DICT_7X7_1000),
    _Diccionario('original', cv.PredefinedDictionaryType.DICT_ARUCO_ORIGINAL),
  ];

  /// Los que se buscan en la cámara: solo los de los marcadores registrados
  /// (más rápido). Si alguno no se pudo leer de su imagen, se buscan todos.
  List<_Diccionario> _activos = const [];

  CameraController? _camara;
  bool _sinCamara = false;

  /// Por "diccionario:id" (p. ej. "6x6:12").
  Map<String, MarcadorAruco> _marcadores = {};

  /// Los que no se pudieron leer de su imagen: solo por número (del nombre).
  Map<int, MarcadorAruco> _porNumero = {};
  bool _cargando = true;
  String? _errorCarga;

  _Deteccion? _actual;

  /// Memoria de 10 s (igual que el visor de Unity, MarcadorConMemoria): si el
  /// marcador sale de cuadro, la información se queda con cuenta regresiva.
  static const _segundosMemoria = 10;
  (String, String, bool)? _memoria; // (título, texto, registrado)
  DateTime? _perdidoEn;

  /// "Respiración" del recuadro de escaneo mientras busca.
  late final AnimationController _respira =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2850))..repeat();
  bool _procesando = false;
  DateTime _ultimoCuadro = DateTime.fromMillisecondsSinceEpoch(0);
  final Set<String> _escaneosRegistrados = {};
  Timer? _limpiador;

  @override
  void initState() {
    super.initState();
    _iniciarCamara();
    _cargarMarcadores();
    _limpiador = Timer.periodic(const Duration(milliseconds: 100), (_) => _actualizarEstado());
  }

  bool get _detectado {
    final a = _actual;
    return a != null && DateTime.now().difference(a.vista) < const Duration(milliseconds: 700);
  }

  void _actualizarEstado() {
    if (!mounted) return;
    final ahora = DateTime.now();
    if (_detectado) {
      final a = _actual!;
      final m = _buscar(a);
      _memoria = m != null
          ? (m.titulo, m.texto, true)
          : ('Marcador ${a.diccionario} #${a.id}', 'Este marcador no está registrado para este lugar.', false);
      _perdidoEn = null;
    } else if (_memoria != null) {
      _perdidoEn ??= ahora;
      if (ahora.difference(_perdidoEn!) > const Duration(seconds: _segundosMemoria)) {
        _memoria = null;
        _perdidoEn = null;
        _actual = null;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _limpiador?.cancel();
    _respira.dispose();
    final camara = _camara;
    _camara = null;
    if (camara != null) {
      if (camara.value.isStreamingImages) camara.stopImageStream().catchError((_) {});
      camara.dispose();
    }
    for (final d in _diccionarios) {
      d.detector.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- cámara

  Future<void> _iniciarCamara() async {
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) throw StateError('sin cámara');
      final trasera = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => camaras.first,
      );
      final controller = CameraController(
        trasera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camara = controller);
      await controller.startImageStream(_alRecibirCuadro);
    } catch (_) {
      if (mounted) setState(() => _sinCamara = true);
    }
  }

  void _alRecibirCuadro(CameraImage imagen) {
    final ahora = DateTime.now();
    // ~6 análisis por segundo: suficiente para que se sienta inmediato sin
    // calentar el teléfono.
    if (_procesando || ahora.difference(_ultimoCuadro) < const Duration(milliseconds: 160)) return;
    _procesando = true;
    _ultimoCuadro = ahora;
    try {
      final deteccion = _detectar(imagen);
      if (deteccion != null && mounted) {
        setState(() => _actual = deteccion);
        _registrarEscaneo(deteccion);
      }
    } catch (_) {
      // Un cuadro dañado no debe tumbar la cámara.
    } finally {
      _procesando = false;
    }
  }

  /// Busca ArUcos en el cuadro (solo el brillo, plano Y). Devuelve el más
  /// grande en pantalla.
  _Deteccion? _detectar(CameraImage imagen) {
    final plano = imagen.planes.first;
    final ancho = imagen.width;
    final alto = imagen.height;
    final paso = ancho > 900 ? 2 : 1; // reducir a ~640 px de ancho: más rápido
    final w = ancho ~/ paso;
    final h = alto ~/ paso;
    final fila = plano.bytesPerRow;
    final origen = plano.bytes;
    final gris = List<int>.filled(w * h, 0);
    for (var y = 0; y < h; y++) {
      final base = y * paso * fila;
      final destino = y * w;
      for (var x = 0; x < w; x++) {
        gris[destino + x] = origen[base + x * paso];
      }
    }

    final mat = cv.Mat.fromList(h, w, cv.MatType.CV_8UC1, gris);
    try {
      _Deteccion? mejor;
      var mejorArea = 0.0;
      final rotacion = _camara?.description.sensorOrientation ?? 90;
      for (final dic in _activos) {
        final (esquinas, ids, rechazados) = dic.detector.detectMarkers(mat);
        try {
          for (var i = 0; i < ids.length; i++) {
            final p = esquinas[i];
            final area = ((p[0].x - p[2].x) * (p[1].y - p[3].y)).abs();
            if (area <= mejorArea) continue;
            mejorArea = area;
            mejor = _Deteccion(
              dic.nombre,
              ids[i],
              [for (var k = 0; k < 4; k++) _aVistaPrevia(p[k].x / w, p[k].y / h, rotacion)],
              DateTime.now(),
            );
          }
        } finally {
          esquinas.dispose();
          ids.dispose();
          rechazados.dispose();
        }
      }
      return mejor;
    } finally {
      mat.dispose();
    }
  }

  /// El sensor entrega los cuadros "acostados"; la vista previa está vertical.
  static Offset _aVistaPrevia(double x, double y, int rotacionSensor) => switch (rotacionSensor) {
        90 => Offset(1 - y, x),
        270 => Offset(y, 1 - x),
        180 => Offset(1 - x, 1 - y),
        _ => Offset(x, y),
      };

  // ------------------------------------------------------------ marcadores

  Future<void> _cargarMarcadores() async {
    try {
      var lista = await _pedirMarcadores(widget.lugar.id);
      // Lugares de demostración (id que no es de la base) o sin marcadores
      // propios: se usan los marcadores generales.
      if (lista.isEmpty) lista = await _pedirMarcadores(null);

      final mapa = <String, MarcadorAruco>{};
      final porNumero = <int, MarcadorAruco>{};
      for (final m in lista) {
        final nombre = (m['nombre'] as String?) ?? '';
        final texto = (m['textoParaMostrar'] as String?) ?? '';
        final lineas = texto.split('\n');
        final titulo = lineas.first.trim().isEmpty ? nombre : lineas.first.trim();
        final cuerpo = lineas.skip(1).join('\n').trim();

        final leido = await _leerImagen(m['urlImagen'] as String?);
        if (leido != null) {
          mapa['${leido.$1}:${leido.$2}'] = MarcadorAruco(
            id: leido.$2, diccionario: leido.$1, nombre: nombre, titulo: titulo, texto: cuerpo);
          continue;
        }
        final id = _idDelNombre(nombre);
        if (id != null) {
          porNumero[id] = MarcadorAruco(id: id, diccionario: null, nombre: nombre, titulo: titulo, texto: cuerpo);
        }
      }
      final usados = {for (final m in mapa.values) m.diccionario};
      final activos = porNumero.isNotEmpty || usados.isEmpty
          ? _diccionarios
          : _diccionarios.where((d) => usados.contains(d.nombre)).toList();
      if (mounted) {
        setState(() {
          _porNumero = porNumero;
          _activos = activos;
        });
      }
      if (mounted) setState(() => _marcadores = mapa);
    } catch (_) {
      if (mounted) setState(() => _errorCarga = 'No se pudieron cargar los marcadores. Revisa tu conexión.');
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
          // Sin datos (p. ej. sin conexión) se buscan todos los tamaños.
          if (_activos.isEmpty) _activos = _diccionarios;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _pedirMarcadores(String? negocioId) async {
    final uri = Uri.parse('$apiUrl/marcadores').replace(
      queryParameters: negocioId == null ? null : {'negocioId': negocioId},
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return const [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ((data['marcadores'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  /// Lee de la imagen que subió el admin qué ArUco es: (diccionario, número).
  Future<(String, int)?> _leerImagen(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;
      final imagen = cv.imdecode(res.bodyBytes, cv.IMREAD_GRAYSCALE);
      if (imagen.isEmpty) {
        imagen.dispose();
        return null;
      }
      // chev.me exporta el marcador pegado a la orilla, sin margen blanco, y
      // el detector necesita ese margen para encontrar el cuadro: se agrega.
      final margen = (imagen.cols > imagen.rows ? imagen.cols : imagen.rows) ~/ 4;
      final conMargen = cv.copyMakeBorder(
        imagen, margen, margen, margen, margen, cv.BORDER_CONSTANT,
        value: cv.Scalar.all(255),
      );
      try {
        for (final mat in [conMargen, imagen]) {
          for (final dic in _diccionarios) {
            final (esquinas, ids, rechazados) = dic.detector.detectMarkers(mat);
            final id = ids.isEmpty ? null : ids.first;
            esquinas.dispose();
            ids.dispose();
            rechazados.dispose();
            if (id != null) return (dic.nombre, id);
          }
        }
        return null;
      } finally {
        conMargen.dispose();
        imagen.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  /// Respaldo: el número que traiga el nombre ("aruco-3" → 3).
  static int? _idDelNombre(String nombre) {
    final m = RegExp(r'(\d+)').firstMatch(nombre);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// Estadística de escaneos (POST /api/marcadores/:nombre/escaneo), una vez por marcador.
  void _registrarEscaneo(_Deteccion d) {
    final marcador = _buscar(d);
    if (marcador == null || !_escaneosRegistrados.add(marcador.nombre)) return;
    http
        .post(Uri.parse('$apiUrl/marcadores/${Uri.encodeComponent(marcador.nombre)}/escaneo'))
        .catchError((_) => http.Response('', 500));
  }

  /// El marcador registrado que corresponde a lo que se ve en la cámara.
  MarcadorAruco? _buscar(_Deteccion d) => _marcadores['${d.diccionario}:${d.id}'] ?? _porNumero[d.id];

  // -------------------------------------------------------------------- UI
  // Diseño "Liquid Glass" del visor de Unity (VisorARResponsive.cs): cámara a
  // pantalla completa, píldora de instrucción arriba, recuadro de escaneo que
  // respira y una tarjeta de vidrio oscuro abajo.

  static const _acento = Color(0xFF63E6E2); // menta
  static const _vidrioCuerpo = Color(0x8C0E1016); // (14,16,22) al 55 %
  static const _vidrioFilo = Color(0x46FFFFFF); // filo que capta la luz
  static const _textoSecundario = Color(0xD2EBF0F5);

  @override
  Widget build(BuildContext context) {
    final camara = _camara;
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final pad = MediaQuery.paddingOf(context);
          final cardH = math.max(200.0, math.min(h * 0.36, 320.0));
          final arriba = pad.top + 12 + 48 + 24; // debajo de la píldora
          final abajo = pad.bottom + 12 + cardH + 24; // encima de la tarjeta
          final lado = math.min(w * 0.64, math.max(0.0, h - arriba - abajo) * 0.8);
          final centroY = arriba + (h - arriba - abajo) / 2;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Cámara a pantalla completa
              if (_sinCamara)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No se pudo abrir la cámara. Revisa que la app tenga permiso de cámara.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                )
              else if (camara != null && camara.value.isInitialized)
                ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: camara.value.previewSize?.height ?? w,
                      height: camara.value.previewSize?.width ?? h,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(camara),
                          if (_detectado)
                            CustomPaint(
                              painter: _MarcoMarcador(_actual!.esquinas, conocido: _buscar(_actual!) != null),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator(color: Colors.white)),

              // Viñeta inferior para dar contraste a la tarjeta
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 420,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0x47000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ),

              // Recuadro de escaneo
              if (lado > 40)
                Positioned(
                  left: (w - lado) / 2 - 20,
                  top: centroY - lado / 2 - 20,
                  width: lado + 40,
                  height: lado + 40,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _respira,
                      builder: (context, _) {
                        final escala = _detectado ? 0.93 : 1 + 0.015 * math.sin(_respira.value * 2 * math.pi);
                        return TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: _detectado ? _acento : Colors.white.withValues(alpha: 0.9)),
                          duration: const Duration(milliseconds: 250),
                          builder: (context, color, _) => AnimatedScale(
                            scale: escala,
                            duration: const Duration(milliseconds: 120),
                            child: CustomPaint(painter: _EsquinasEscaneo(color ?? Colors.white, lado)),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Arriba: atrás + píldora de instrucción
              Positioned(
                top: pad.top + 12,
                left: 16,
                right: 16,
                height: 48,
                child: Row(
                  children: [
                    _Vidrio(
                      radio: 24,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          tooltip: 'Volver',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Center(
                        child: _Vidrio(
                          radio: 24,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: SizedBox(
                              height: 48,
                              child: Center(
                                child: Text(
                                  _sinCamara ? widget.lugar.nombre : 'Apunta la cámara al marcador',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 58),
                  ],
                ),
              ),

              // Abajo: tarjeta de vidrio
              Positioned(
                left: 12,
                right: 12,
                bottom: pad.bottom + 12,
                height: cardH,
                child: _tarjeta(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tarjeta() {
    final detectado = _detectado;
    final memoria = _memoria;
    final perdido = _perdidoEn;
    final restante = perdido == null
        ? 0.0
        : (_segundosMemoria - DateTime.now().difference(perdido).inMilliseconds / 1000).clamp(0.0, 10.0);
    final enMemoria = !detectado && memoria != null && perdido != null;

    // Título y texto: lo detectado (o en memoria) o el estado de la pantalla.
    String titulo;
    String texto;
    if (memoria != null) {
      titulo = memoria.$1;
      texto = memoria.$2;
    } else if (_errorCarga != null) {
      (titulo, texto) = ('Sin conexión', _errorCarga!);
    } else if (_cargando) {
      (titulo, texto) = ('Preparando la cámara…', 'Cargando los marcadores de este lugar.');
    } else if (_marcadores.isEmpty && _porNumero.isEmpty) {
      (titulo, texto) = ('Escanea el marcador', 'Este lugar todavía no tiene marcadores registrados.');
    } else {
      (titulo, texto) = ('Escanea el marcador', 'Centra el marcador en el recuadro y mantén el teléfono quieto.');
    }

    // Etiqueta de estado: punto de color + texto
    final String etiqueta;
    final Color punto;
    if (detectado) {
      etiqueta = (memoria?.$3 ?? true) ? 'Marcador detectado' : 'Marcador no registrado';
      punto = (memoria?.$3 ?? true) ? _acento : Colors.amber;
    } else if (enMemoria) {
      etiqueta = 'Se oculta en ${restante.ceil()} s';
      punto = _acento;
    } else {
      etiqueta = 'Buscando marcador';
      final t = DateTime.now().millisecondsSinceEpoch / 1000;
      punto = Colors.white.withValues(alpha: 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 3.5)));
    }

    return _Vidrio(
      radio: 28,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  etiqueta,
                  style: const TextStyle(
                    color: _textoSecundario,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            // Descripción con scroll y desvanecido abajo si no cabe
            Expanded(
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0, 0.82, 1],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    texto,
                    style: const TextStyle(color: _textoSecundario, fontSize: 15, height: 1.45),
                  ),
                ),
              ),
            ),
            // Barra de tiempo de la memoria
            AnimatedOpacity(
              opacity: enMemoria ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: restante / _segundosMemoria,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  valueColor: const AlwaysStoppedAnimation(_acento),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel de vidrio: desenfoca lo que hay detrás (la cámara), tinte oscuro
/// translúcido y un filo fino que capta la luz.
class _Vidrio extends StatelessWidget {
  final double radio;
  final Widget child;

  const _Vidrio({required this.radio, required this.child});

  @override
  Widget build(BuildContext context) {
    final borde = BorderRadius.circular(radio);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borde,
        boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: borde,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: _ArucoPageState._vidrioCuerpo,
              borderRadius: borde,
              border: Border.all(color: _ArucoPageState._vidrioFilo, width: 1),
            ),
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}

/// Las 4 esquinas redondeadas del recuadro de escaneo.
class _EsquinasEscaneo extends CustomPainter {
  final Color color;
  final double lado;

  _EsquinasEscaneo(this.color, this.lado);

  @override
  void paint(Canvas canvas, Size size) {
    final l = lado;
    final x0 = (size.width - l) / 2;
    final y0 = (size.height - l) / 2;
    final largo = math.min(36.0, l * 0.22);
    const radio = 18.0;
    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    void esquina(double x, double y, double dx, double dy) {
      final p = Path()
        ..moveTo(x, y + dy * largo)
        ..lineTo(x, y + dy * radio)
        ..quadraticBezierTo(x, y, x + dx * radio, y)
        ..lineTo(x + dx * largo, y);
      canvas.drawPath(p, pincel);
    }

    esquina(x0, y0, 1, 1);
    esquina(x0 + l, y0, -1, 1);
    esquina(x0, y0 + l, 1, -1);
    esquina(x0 + l, y0 + l, -1, -1);
  }

  @override
  bool shouldRepaint(_EsquinasEscaneo old) => old.color != color || old.lado != lado;
}

class _MarcoMarcador extends CustomPainter {
  final List<Offset> esquinas;
  final bool conocido;

  _MarcoMarcador(this.esquinas, {required this.conocido});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(esquinas[0].dx * size.width, esquinas[0].dy * size.height);
    for (final p in esquinas.skip(1)) {
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    path.close();
    final color = conocido ? const Color(0xFF63E6E2) : Colors.amber;
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_MarcoMarcador old) => old.esquinas != esquinas || old.conocido != conocido;
}
