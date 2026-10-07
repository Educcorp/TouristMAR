import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/pages/ra_ubicacion_page.dart';
import 'package:touristmar_web/services/experiencias_launcher.dart';
import 'package:touristmar_web/services/ra_geo_service.dart';
import 'package:touristmar_web/widgets/experiencias/experiencias_lugar.dart' show ExperienciaSituacion;

/// FIME, con su pin real.
const _fime = Lugar(
  id: 'f24442e4-6613-4427-99df-a7f962d6b99e',
  nombre: 'Facultad de ingenieria electromecanica',
  categoriaTexto: 'Otro',
  descripcion: 'Universidad de Colima Campus El Naranjo',
  portada: 'assets/images/place-playa-audiencia.jpg',
  ubicacion: Coordenadas(19.12397051892223, -104.4000125955125),
);

/// Punto de interés: la entrada, con radio visible 100 m y cercano 10 m.
const _entrada = PuntoRaGeo(
  titulo: 'Entrada principal',
  resumen: 'Acceso por la carretera Manzanillo-Cihuatlán',
  detalle: 'Aquí se encuentra la caseta de acceso al campus.',
  ubicacion: Coordenadas(19.12397051892223, -104.4000125955125),
);

/// Coordenadas a [metros] al sur del punto (el punto queda al norte, rumbo 0°).
// 111 195 m por grado de latitud: el mismo radio terrestre que distanciaMetros.
Coordenadas _alSur(double metros) => Coordenadas(_entrada.ubicacion.lat - metros / 111195, _entrada.ubicacion.lng);

/// Un cuadro para que llegue la lectura del GPS y otro para dibujar lo que
/// cambió con ella.
Future<void> _dibujar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

class _Sensores {
  final gps = StreamController<Coordenadas>();
  final brujula = StreamController<double>();
}

/// Como la app móvil con Unity: anota qué experiencia se pidió abrir.
class _LauncherConUnity implements ExperienciasLauncher {
  final abiertas = <ExperienciaTipo>[];

  @override
  bool soporta(ExperienciaTipo tipo) => true;

  @override
  bool mideDistancia(ExperienciaTipo tipo) => tipo == ExperienciaTipo.arGeo;

  @override
  Future<void> abrir(BuildContext context, Lugar lugar, ExperienciaTipo tipo) async => abiertas.add(tipo);
}

Future<_Sensores> _montar(WidgetTester tester, {List<PuntoRaGeo>? puntos, bool tieneMarcadores = false}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = _Sensores();
  // Sin `await`: dentro del tiempo simulado de testWidgets se quedaría esperando.
  addTearDown(() {
    unawaited(s.gps.close());
    unawaited(s.brujula.close());
  });
  await tester.pumpWidget(MaterialApp(
    home: RaUbicacionPage(
      lugar: _fime,
      puntos: puntos ?? const [_entrada],
      tieneMarcadores: tieneMarcadores,
      ubicaciones: s.gps.stream,
      rumbos: s.brujula.stream,
      usarCamara: false,
    ),
  ));
  return s;
}

void main() {
  test('cualquier lugar con pin tiene RA por geolocalización; sin puntos, su pin hace de punto', () {
    expect(ExperienciaSituacion.calcular(_fime, ExperienciaTipo.arGeo, null).estado, isNot(ExperienciaEstado.noDisponible));
    final pin = PuntoRaGeo.delLugar(_fime);
    expect(pin.titulo, _fime.nombre);
    expect(pin.radioVisible, radioVisibleDefault);
    expect(pin.radioCercano, radioCercanoDefault);
    expect(rumboHacia(_alSur(500), _entrada.ubicacion), closeTo(0, 0.5));
    expect(diferenciaAngulo(10, 350), 20);
  });

  testWidgets('lejos (fuera del radio visible) solo guía con distancia y dirección', (tester) async {
    final s = await _montar(tester);
    s.gps.add(_alSur(500));
    s.brujula.add(0);
    await _dibujar(tester);

    expect(find.textContaining('El punto más cercano, Entrada principal, está a 500 m hacia el norte'), findsOneWidget);
    expect(find.text('Acceso por la carretera Manzanillo-Cihuatlán'), findsNothing, reason: 'todavía sin marcador');
  });

  testWidgets('dentro del radio visible aparece el marcador flotante con el resumen', (tester) async {
    final s = await _montar(tester);
    s.gps.add(_alSur(60));
    s.brujula.add(3); // casi al norte: el punto está en la vista
    await tester.pump();

    expect(find.text('Entrada principal'), findsOneWidget);
    expect(find.text('Acceso por la carretera Manzanillo-Cihuatlán'), findsOneWidget);
    expect(find.text('60 m'), findsOneWidget);
    expect(find.text('¡Llegaste!'), findsNothing);
  });

  testWidgets('en el radio visible pero viendo a otro lado indica hacia dónde girar', (tester) async {
    final s = await _montar(tester);
    s.gps.add(_alSur(60));
    s.brujula.add(270); // viendo al oeste: el punto queda 90° a la derecha
    await tester.pump();

    expect(find.text('Gira a la derecha 90° · Entrada principal'), findsOneWidget);
  });

  testWidgets('dentro del radio cercano abre la guía completa, y no parpadea en el borde', (tester) async {
    final s = await _montar(tester);
    s.gps.add(_alSur(6));
    await _dibujar(tester);

    expect(find.text('¡Llegaste!'), findsOneWidget);
    expect(find.text('Aquí se encuentra la caseta de acceso al campus.'), findsOneWidget);

    // A 13 m (radio 10 + 5 de margen) la guía sigue abierta: el GPS tiembla.
    s.gps.add(_alSur(13));
    await _dibujar(tester);
    expect(find.text('¡Llegaste!'), findsOneWidget);

    // Ya lejos se cierra y vuelve el marcador.
    s.gps.add(_alSur(40));
    await _dibujar(tester);
    expect(find.text('¡Llegaste!'), findsNothing);
  });

  testWidgets('al cerrar la guía se puede volver a abrir sin moverse', (tester) async {
    final s = await _montar(tester);
    s.gps.add(_alSur(4));
    await _dibujar(tester);

    await tester.tap(find.text('Volver a la cámara'));
    await _dibujar(tester);
    expect(find.text('Estás en Entrada principal.'), findsOneWidget);

    await tester.tap(find.text('Ver guía'));
    await _dibujar(tester);
    expect(find.text('¡Llegaste!'), findsOneWidget);
  });

  testWidgets('con varios puntos dentro del radio visible los cuenta', (tester) async {
    final s = await _montar(tester, puntos: [
      _entrada,
      PuntoRaGeo(titulo: 'Explanada', ubicacion: Coordenadas(_entrada.ubicacion.lat + 0.0003, _entrada.ubicacion.lng)),
    ]);
    s.gps.add(_alSur(30));
    s.brujula.add(0);
    await _dibujar(tester);

    expect(find.text('Hay 2 puntos de interés cerca. Apunta la cámara para verlos.'), findsOneWidget);
    expect(find.text('Entrada principal'), findsOneWidget);
    expect(find.text('Explanada'), findsOneWidget);
  });

  testWidgets('sin brújula (computadora) ofrece activarla', (tester) async {
    final s = await _montar(tester);
    s.gps.add(_alSur(500));
    await _dibujar(tester);

    expect(find.text('Activar brújula'), findsOneWidget);
  });

  group('paso a los marcadores de Unity al llegar', () {
    testWidgets('sin marcadores en el lugar no ofrece el botón', (tester) async {
      final s = await _montar(tester);
      s.gps.add(_alSur(4));
      await _dibujar(tester);

      expect(find.text('¡Llegaste!'), findsOneWidget);
      expect(find.text('Abrir RA con marcadores'), findsNothing);
    });

    testWidgets('con marcadores abre la escena de marcadores de Unity', (tester) async {
      final original = ExperienciasLauncher.current;
      final launcher = _LauncherConUnity();
      ExperienciasLauncher.current = launcher;
      addTearDown(() => ExperienciasLauncher.current = original);

      final s = await _montar(tester, tieneMarcadores: true);
      s.gps.add(_alSur(4));
      await _dibujar(tester);

      await tester.ensureVisible(find.text('Abrir RA con marcadores'));
      await tester.tap(find.text('Abrir RA con marcadores'));
      await _dibujar(tester);

      expect(launcher.abiertas, [ExperienciaTipo.arMarcador]);
    });

    testWidgets('lejos del punto no aparece (solo en la capa cercana)', (tester) async {
      final s = await _montar(tester, tieneMarcadores: true);
      s.gps.add(_alSur(60));
      s.brujula.add(0);
      await _dibujar(tester);

      expect(find.text('Abrir RA con marcadores'), findsNothing);
    });

    testWidgets('en la web (sin Unity) avisa que se abre desde la app móvil', (tester) async {
      final s = await _montar(tester, tieneMarcadores: true);
      s.gps.add(_alSur(4));
      await _dibujar(tester);

      await tester.ensureVisible(find.text('Abrir RA con marcadores'));
      await tester.tap(find.text('Abrir RA con marcadores'));
      await _dibujar(tester);

      expect(find.text('La RA con marcadores se abre desde la app móvil.'), findsOneWidget);
    });
  });

  testWidgets('el panel y la guía quedan abajo, dentro de la pantalla (800 px de alto)', (tester) async {
    final s = await _montar(tester, tieneMarcadores: true);
    s.gps.add(_alSur(500));
    await _dibujar(tester);
    final panel = tester.getRect(find.textContaining('El punto más cercano'));
    expect(panel.bottom, greaterThan(650));
    expect(panel.bottom, lessThanOrEqualTo(800));

    s.gps.add(_alSur(4));
    await _dibujar(tester);
    final volver = tester.getRect(find.text('Volver a la cámara'));
    final llegaste = tester.getRect(find.text('¡Llegaste!'));
    expect(volver.bottom, lessThanOrEqualTo(800));
    expect(volver.top, greaterThan(llegaste.bottom), reason: 'el botón va debajo del título, no encima');
    expect(llegaste.top, greaterThanOrEqualTo(0));
  });
}
