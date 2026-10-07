import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/pages/ruta_lugar_page.dart';
import 'package:touristmar_web/services/ruta_service.dart';

/// "Playa La Audiencia" es una de las playas con RA por ubicación.
const _playa = Lugar(
  id: 'l-1',
  nombre: 'Playa La Audiencia',
  categoriaTexto: 'Playa',
  portada: 'assets/images/place-playa-audiencia.jpg',
  ubicacion: Coordenadas(19.1006, -104.3399),
  radioDesbloqueo: 50,
);

/// Respuesta de OSRM: 1.2 km a pie en 15 min.
MockClient _osrm({bool falla = false}) => MockClient((request) async {
      if (falla) return http.Response('', 500);
      return http.Response(
        jsonEncode({
          'code': 'Ok',
          'routes': [
            {
              'distance': 1200,
              'duration': 900,
              'geometry': {
                'coordinates': [
                  [-104.3300, 19.0950],
                  [-104.3350, 19.0980],
                  [-104.3399, 19.1006],
                ],
              },
            },
          ],
        }),
        200,
      );
    });

Future<StreamController<Coordenadas>> _montar(WidgetTester tester, MockClient client) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Con la fuente de pruebas (Ahem) la franja de créditos de OpenStreetMap
  // no cabe; con la real sí.
  final onError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (!(d.toString().contains('flutter_map') && d.toString().contains('overflowed'))) onError?.call(d);
  };
  addTearDown(() => FlutterError.onError = onError);

  final gps = StreamController<Coordenadas>();
  // Sin `await`: dentro del tiempo simulado de testWidgets se quedaría esperando.
  addTearDown(() => unawaited(gps.close()));
  await tester.pumpWidget(MaterialApp(
    home: RutaLugarPage(lugar: _playa, rutaService: RutaService(client: client), ubicaciones: gps.stream),
  ));
  return gps;
}

void main() {
  testWidgets('dibuja la ruta a pie en nuestro mapa; lejos de la zona no deja abrir la RA', (tester) async {
    final gps = await _montar(tester, _osrm());
    expect(find.text('Buscando tu ubicación…'), findsOneWidget);

    gps.add(const Coordenadas(19.0950, -104.3300));
    await tester.pumpAndSettle();

    expect(find.text('1.2 km a pie · 15 min'), findsOneWidget);
    expect(find.textContaining('para la zona de realidad aumentada'), findsOneWidget);
    final boton = tester.widget<FilledButton>(find.ancestor(of: find.text('Abrir realidad aumentada'), matching: find.byType(FilledButton)));
    expect(boton.onPressed, isNull);
  });

  testWidgets('dentro del radio avisa que estás en la zona y habilita la RA', (tester) async {
    final gps = await _montar(tester, _osrm());

    gps.add(const Coordenadas(19.10065, -104.33995)); // a ~7 m del punto
    await tester.pumpAndSettle();

    expect(find.text('Estás en la zona de realidad aumentada.'), findsOneWidget);
    final boton = tester.widget<FilledButton>(find.ancestor(of: find.text('Abrir realidad aumentada'), matching: find.byType(FilledButton)));
    expect(boton.onPressed, isNotNull);
  });

  testWidgets('si no se puede calcular la ruta por calles, muestra la distancia en línea recta', (tester) async {
    final gps = await _montar(tester, _osrm(falla: true));

    gps.add(const Coordenadas(19.0950, -104.3300));
    await tester.pumpAndSettle();

    expect(find.textContaining('en línea recta'), findsOneWidget);
  });

  testWidgets('sin permiso de ubicación ofrece volver a intentarlo', (tester) async {
    final gps = await _montar(tester, _osrm());

    unawaited(gps.close()); // el stream termina sin posiciones = sin permiso
    await tester.pumpAndSettle();

    expect(find.text('Activa tu ubicación para ver la ruta.'), findsOneWidget);
    expect(find.text('Usar mi ubicación'), findsOneWidget);
  });

  testWidgets('el panel con la distancia queda abajo de la pantalla (1400 px de alto)', (tester) async {
    final gps = await _montar(tester, _osrm());
    gps.add(const Coordenadas(19.0950, -104.3300));
    await tester.pumpAndSettle();

    final resumen = tester.getRect(find.text('1.2 km a pie · 15 min'));
    expect(resumen.top, greaterThan(1000));
    expect(resumen.bottom, lessThanOrEqualTo(1400));
  });
}
