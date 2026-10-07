import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/pages/admin/admin_ra_geo_widgets.dart';
import 'package:touristmar_web/services/auth_service.dart';
import 'package:touristmar_web/services/ra_geo_service.dart';
import 'package:touristmar_web/services/session_storage.dart';

const _fimeId = 'f24442e4-6613-4427-99df-a7f962d6b99e';

final _fime = NegocioSummary.fromJson({
  'id': _fimeId,
  'nombre': 'Facultad de ingenieria electromecanica',
  'categoria': 'Otro',
  'descripcion': 'Universidad de Colima Campus El Naranjo',
  'estado': 'aprobado',
  'email': 'super@touristmar.mx',
  'contacto': 'Super',
  'solicitadoEn': '2026-10-06T00:00:00.000Z',
  'latitud': 19.12397051892223,
  'longitud': -104.4000125955125,
});

void main() {
  late List<Map<String, dynamic>> guardados;
  late List<String> peticiones;

  MockClient servidor() => MockClient((request) async {
        peticiones.add('${request.method} ${request.url.path}');
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'puntos': guardados}), 200);
        }
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final punto = {'id': 'p-${guardados.length + 1}', 'orden': guardados.length, ...body};
          guardados.add(punto);
          return http.Response(jsonEncode({'punto': punto}), 201);
        }
        return http.Response('{}', 404);
      });

  setUp(() {
    guardados = [];
    peticiones = [];
    SessionStorage.saveToken('jwt');
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      // Créditos de OpenStreetMap de los mapas con la fuente de pruebas (Ahem).
      if (!(d.toString().contains('flutter_map') && d.toString().contains('overflowed'))) onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: PuntosRaGeoSection(lugar: _fime, service: RaGeoService(client: servidor()))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('sin puntos explica que se usa el pin del lugar con los radios por defecto', (tester) async {
    await montar(tester);

    expect(peticiones, ['GET /api/admin/ra-geo/lugares/$_fimeId/puntos']);
    expect(find.textContaining('la app usa el pin del lugar como punto único'), findsOneWidget);
    expect(find.textContaining('marcador a 100 m y guía completa a 10 m'), findsOneWidget);
  });

  testWidgets('el admin agrega un punto con sus coordenadas y los dos radios', (tester) async {
    await montar(tester);

    await tester.tap(find.text('Agregar punto'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo punto de interés'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Facultad de ingenieria electromecanica'), 'Entrada principal');
    await tester.enterText(
      find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Ej. Facultad de Ingeniería Electromecánica de la UdeC'),
      'Acceso por la carretera',
    );
    await tester.enterText(
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '19.12397051892223, -104.4000125955125'),
      '19.1241, -104.4002',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Guardar punto'));
    await tester.tap(find.text('Guardar punto'));
    await tester.pumpAndSettle();

    expect(guardados.single, containsPair('titulo', 'Entrada principal'));
    expect(guardados.single, containsPair('resumen', 'Acceso por la carretera'));
    expect(guardados.single, containsPair('latitud', 19.1241));
    expect(guardados.single, containsPair('longitud', -104.4002));
    expect(guardados.single, containsPair('radioVisible', 100.0));
    expect(guardados.single, containsPair('radioCercano', 10.0));
    // Se vuelve a cargar la lista y aparece el punto.
    expect(find.text('Entrada principal'), findsOneWidget);
    expect(find.text('Punto agregado'), findsOneWidget);
  });

  testWidgets('el título es obligatorio', (tester) async {
    await montar(tester);
    await tester.tap(find.text('Agregar punto'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Facultad de ingenieria electromecanica'), '');
    await tester.ensureVisible(find.text('Guardar punto'));
    await tester.tap(find.text('Guardar punto'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe un título'), findsOneWidget);
    expect(guardados, isEmpty);
  });
}
