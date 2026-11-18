import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/services/auth_service.dart' show apiUrl;

/// Un marcador del lugar, ya con el número ArUco que trae impreso.
class MarcadorAruco {
  final int id;
  final String nombre;
  final String titulo;
  final String texto;

  const MarcadorAruco({required this.id, required this.nombre, required this.titulo, required this.texto});
}

/// Lo que se ve ahora mismo en la cámara.
class _Deteccion {
  final int id;

  /// Esquinas del marcador en la vista previa (0..1, vertical).
  final List<Offset> esquinas;
  final DateTime vista;

  _Deteccion(this.id, this.esquinas, this.vista);
}

/// RA con marcadores **ArUco** (diccionario 4x4, los de https://chev.me/arucogen/).
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

class _ArucoPageState extends State<ArucoPage> {
  /// 4x4: los IDs 0-49 son iguales en DICT_4X4_50/100/250/1000, así que con el
  /// de 1000 se leen todos los de chev.me (opción "4x4 (50, 100, 250, 1000)").
  late final cv.ArucoDetector _detector = cv.ArucoDetector.create(
    cv.ArucoDictionary.predefined(cv.PredefinedDictionaryType.DICT_4X4_1000),
    cv.ArucoDetectorParameters.empty(),
  );

  CameraController? _camara;
  bool _sinCamara = false;

  Map<int, MarcadorAruco> _marcadores = {};
  bool _cargando = true;
  String? _errorCarga;

  _Deteccion? _actual;
  bool _procesando = false;
  DateTime _ultimoCuadro = DateTime.fromMillisecondsSinceEpoch(0);
  final Set<int> _escaneosRegistrados = {};
  Timer? _limpiador;

  @override
  void initState() {
    super.initState();
    _iniciarCamara();
    _cargarMarcadores();
    // Si el marcador sale de cuadro, la tarjeta se queda un momento y luego se quita.
    _limpiador = Timer.periodic(const Duration(milliseconds: 400), (_) {
      final actual = _actual;
      if (actual != null && DateTime.now().difference(actual.vista) > const Duration(milliseconds: 1500)) {
        if (mounted) setState(() => _actual = null);
      }
    });
  }

  @override
  void dispose() {
    _limpiador?.cancel();
    final camara = _camara;
    _camara = null;
    if (camara != null) {
      if (camara.value.isStreamingImages) camara.stopImageStream().catchError((_) {});
      camara.dispose();
    }
    _detector.dispose();
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
        _registrarEscaneo(deteccion.id);
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
      final (esquinas, ids, rechazados) = _detector.detectMarkers(mat);
      try {
        if (ids.isEmpty) return null;
        var mejor = -1;
        var mejorArea = 0.0;
        for (var i = 0; i < ids.length; i++) {
          final p = esquinas[i];
          final area = ((p[0].x - p[2].x) * (p[1].y - p[3].y)).abs();
          if (area > mejorArea) {
            mejorArea = area;
            mejor = i;
          }
        }
        final p = esquinas[mejor];
        final rotacion = _camara?.description.sensorOrientation ?? 90;
        final puntos = [
          for (var k = 0; k < 4; k++) _aVistaPrevia(p[k].x / w, p[k].y / h, rotacion),
        ];
        return _Deteccion(ids[mejor], puntos, DateTime.now());
      } finally {
        esquinas.dispose();
        ids.dispose();
        rechazados.dispose();
      }
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

      final mapa = <int, MarcadorAruco>{};
      for (final m in lista) {
        final nombre = (m['nombre'] as String?) ?? '';
        final texto = (m['textoParaMostrar'] as String?) ?? '';
        final id = await _idDeLaImagen(m['urlImagen'] as String?) ?? _idDelNombre(nombre);
        if (id == null) continue;
        final lineas = texto.split('\n');
        mapa[id] = MarcadorAruco(
          id: id,
          nombre: nombre,
          titulo: lineas.first.trim().isEmpty ? nombre : lineas.first.trim(),
          texto: lineas.skip(1).join('\n').trim(),
        );
      }
      if (mounted) setState(() => _marcadores = mapa);
    } catch (_) {
      if (mounted) setState(() => _errorCarga = 'No se pudieron cargar los marcadores. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _cargando = false);
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

  /// Lee el número ArUco de la imagen que subió el admin.
  Future<int?> _idDeLaImagen(String? url) async {
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
          final (esquinas, ids, rechazados) = _detector.detectMarkers(mat);
          final id = ids.isEmpty ? null : ids.first;
          esquinas.dispose();
          ids.dispose();
          rechazados.dispose();
          if (id != null) return id;
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
  void _registrarEscaneo(int id) {
    final marcador = _marcadores[id];
    if (marcador == null || !_escaneosRegistrados.add(id)) return;
    http
        .post(Uri.parse('$apiUrl/marcadores/${Uri.encodeComponent(marcador.nombre)}/escaneo'))
        .catchError((_) => http.Response('', 500));
  }

  // -------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final camara = _camara;
    final actual = _actual;
    final marcador = actual == null ? null : _marcadores[actual.id];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('RA · ${widget.lugar.nombre}', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_sinCamara)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No se pudo abrir la cámara. Revisa que la app tenga permiso de cámara.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            )
          else if (camara == null || !camara.value.isInitialized)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            Center(
              child: AspectRatio(
                aspectRatio: 1 / camara.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(camara),
                    if (actual != null)
                      CustomPaint(painter: _MarcoMarcador(actual.esquinas, conocido: marcador != null)),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(child: _tarjeta(actual, marcador)),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(_Deteccion? actual, MarcadorAruco? marcador) {
    var titulo = '';
    var texto = '';
    var icono = Icons.place;
    if (_errorCarga != null) {
      (titulo, texto, icono) = ('Sin conexión', _errorCarga!, Icons.wifi_off);
    } else if (_cargando) {
      (titulo, texto, icono) = ('Preparando la cámara…', 'Cargando los marcadores de este lugar.', Icons.hourglass_top);
    } else if (actual == null) {
      (titulo, texto, icono) = (
        'Apunta a un marcador',
        _marcadores.isEmpty
            ? 'Este lugar todavía no tiene marcadores registrados.'
            : 'Encuadra el código blanco y negro y mantén el teléfono quieto.',
        Icons.qr_code_scanner,
      );
    } else if (marcador == null) {
      (titulo, texto, icono) = ('Marcador #${actual.id}', 'Este marcador no está registrado para este lugar.', Icons.help_outline);
    } else {
      (titulo, texto, icono) = (marcador.titulo, marcador.texto, Icons.place);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey('$titulo|$texto'),
        constraints: const BoxConstraints(maxHeight: 280),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: marcador != null ? const Color(0xFF34D3C6) : Colors.white24),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, color: marcador != null ? const Color(0xFF34D3C6) : Colors.white70),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (texto.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(texto, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.35)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Recuadro sobre el marcador detectado.
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
    final color = conocido ? const Color(0xFF34D3C6) : Colors.amber;
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
