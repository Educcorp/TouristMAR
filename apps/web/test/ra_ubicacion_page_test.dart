import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/pages/ra_ubicacion_page.dart';
import 'package:touristmar_web/services/experiencias_launcher.dart';
import 'package:touristmar_web/widgets/experiencias/experiencias_lugar.dart' show ExperienciaSituacion;

/// Un negocio cualquiera con pin (no es una de las playas de Unity).
const _negocio = Lugar(
  id: 'n-1',
  nombre: 'Mariscos El Faro',
  categoriaTexto: 'Restaurante',
  descripcion: 'Mariscos frescos frente al mar.',
  portada: 'assets/images/place-playa-audiencia.jpg',
  ubicacion: Coordenadas(19.1006, -104.3399),
  radioDesbloqueo: 50,
);

/// ~1.1 km al sur del negocio: desde aquí el negocio queda al norte (rumbo 0°).
const _alSur = Coordenadas(19.0906, -104.3399);

class _Sensores {
  final gps = StreamController<Coordenadas>();
  final brujula = StreamController<double>();
}

Future<_Sensores> _montar(WidgetTester tester) async {
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
    home: RaUbicacionPage(lugar: _negocio, ubicaciones: s.gps.stream, rumbos: s.brujula.stream, usarCamara: false),
  ));
  return s;
}

void main() {
  test('cualquier lugar con pin tiene RA por ubicación, no solo las playas de Unity', () {
    final situacion = ExperienciaSituacion.calcular(_negocio, ExperienciaTipo.arGeo, null);
    expect(situacion.estado, isNot(ExperienciaEstado.noDisponible));
    expect(rumboHacia(_alSur, _negocio.ubicacion!), closeTo(0, 0.5));
    expect(diferenciaAngulo(10, 350), 20);
  });

  testWidgets('apuntando hacia el lugar muestra su letrero con la distancia', (tester) async {
    final s = await _montar(tester);
    s.gps.add(_alSur);
    s.brujula.add(5); // casi al norte
    await tester.pump();

    expect(find.text('Mariscos El Faro'), findsOneWidget);
    expect(find.text('1.1 km'), findsOneWidget);
    expect(find.textContaining('Gira a la'), findsNothing);
  });

  testWidgets('apuntando a otro lado indica hacia dónde girar', (tester) async {
    final s = await _montar(tester);
    s.gps.add(_alSur);
    s.brujula.add(270); // viendo al oeste: el lugar queda 90° a la derecha
    await tester.pump();

    expect(find.text('Gira a la derecha 90°'), findsOneWidget);
    expect(find.text('Mariscos El Faro'), findsNothing);
  });

  testWidgets('dentro del radio dice "¡Llegaste!" y muestra la descripción', (tester) async {
    final s = await _montar(tester);
    s.gps.add(const Coordenadas(19.10065, -104.33995));
    await tester.pump();

    expect(find.text('¡Llegaste!'), findsOneWidget);
    expect(find.text('Mariscos frescos frente al mar.'), findsOneWidget);
  });

  testWidgets('sin brújula (computadora) da la dirección cardinal', (tester) async {
    final s = await _montar(tester);
    s.gps.add(_alSur);
    await tester.pump();

    expect(find.textContaining('hacia el norte'), findsOneWidget);
    expect(find.text('Activar brújula'), findsOneWidget);
  });
}
