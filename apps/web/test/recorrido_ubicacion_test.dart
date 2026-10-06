import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/pages/admin/admin_recorridos_page.dart';
import 'package:touristmar_web/services/auth_service.dart';
import 'package:touristmar_web/services/recorridos_service.dart';
import 'package:touristmar_web/services/session_storage.dart';

RecorridoPublico _publico(String nombre, String titulo, {double? lat, double? lng, String negocioId = ''}) =>
    RecorridoPublico.fromJson({
      'nombre': nombre,
      'textoParaMostrar': '$titulo\nInfo',
      'negocioId': negocioId,
      'urlPortada': 'https://cdn/$nombre.jpg',
      'tieneUbicacion': lat != null,
      'latitud': lat ?? 0,
      'longitud': lng ?? 0,
      'escenaInicial': 'e-1',
      'escenas': [
        {'id': 'e-1', 'titulo': 'Entrada', 'urlImagen': 'https://cdn/$nombre/1.jpg', 'enlaces': []},
      ],
    });

void main() {
  test('el pin del recorrido se lee de la API (sin pin = null, no 0,0)', () {
    final fime = _publico('fime_360', 'FIME', lat: 19.12492145230218, lng: -104.40020700589847);
    expect(fime.latitud, 19.12492145230218);
    expect(fime.tieneUbicacion, isTrue);
    expect(_publico('sin_pin_360', 'Sin pin').tieneUbicacion, isFalse);
  });

  test('un recorrido con pin propio aparece en el mapa; el de un lugar que ya está, no se duplica', () {
    const playa = Lugar(id: 'n-1', nombre: 'Playa La Audiencia', categoriaTexto: 'Playa', portada: '', ubicacion: Coordenadas(19.1, -104.3));
    final lugares = lugaresDeRecorridos([
      _publico('fime_360', 'Facultad de Ingeniería Electromecánica', lat: 19.12492145230218, lng: -104.40020700589847),
      _publico('audiencia_360', 'Playa La Audiencia', lat: 19.1, lng: -104.3, negocioId: 'n-1'),
      _publico('sin_pin_360', 'Mirador'),
    ], [playa]);

    expect(lugares.map((l) => l.nombre), ['Facultad de Ingeniería Electromecánica']);
    expect(lugares.single.ubicacion!.lat, 19.12492145230218);
    // Al tocarlo, "Ver en 360°" encuentra su recorrido.
    expect(
      recorridoDeLugar([_publico('fime_360', 'Facultad de Ingeniería Electromecánica')],
              lugarId: lugares.single.id, lugarNombre: lugares.single.nombre)!
          .nombre,
      'fime_360',
    );
  });

  testWidgets('dentro de un lugar, "Nuevo recorrido" queda ligado al lugar y toma su pin', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      // Créditos de OpenStreetMap del mini mapa con la fuente de pruebas (Ahem).
      if (!(d.toString().contains('flutter_map') && d.toString().contains('overflowed'))) onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);
    SessionStorage.saveToken('jwt');

    Map<String, dynamic>? creado;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/admin/recorridos')) {
        return http.Response(jsonEncode({'recorridos': []}), 200);
      }
      if (request.method == 'POST') {
        creado = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'recorrido': {'id': 'r-1', ...creado!, 'negocioNombre': 'FIME', 'activo': true, 'escenas': []},
          }),
          201,
        );
      }
      return http.Response('{}', 404);
    });

    final fime = NegocioSummary(
      id: 'n-fime',
      nombre: 'Facultad de Ingeniería Electromecánica',
      estado: 'aprobado',
      email: '',
      contacto: '',
      solicitadoEn: DateTime(2026),
      latitud: 19.12492145230218,
      longitud: -104.40020700589847,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RecorridosLugarSection(lugar: fime, recorridosService: RecorridosService(client: client)),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nuevo recorrido'));
    await tester.pumpAndSettle();
    // El pin del lugar ya viene puesto.
    expect(
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '19.12492145230218, -104.40020700589847'),
      findsOneWidget,
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Ej. playa_audiencia_360'), 'fime_360');
    await tester.enterText(find.widgetWithText(TextFormField, 'Ej. Playa La Audiencia'), 'FIME');
    await tester.enterText(find.widgetWithText(TextFormField, 'Ej. Recorre la playa desde el malecón hasta las palapas.'), 'Explanada y edificios.');
    await tester.ensureVisible(find.text('Crear y subir escenarios'));
    await tester.tap(find.text('Crear y subir escenarios'));
    await tester.pumpAndSettle();

    expect(creado, containsPair('negocioId', 'n-fime'));
    expect(creado, containsPair('latitud', 19.12492145230218));
    expect(creado, containsPair('longitud', -104.40020700589847));
  });
}
