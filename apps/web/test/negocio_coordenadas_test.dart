import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/models/business_profile.dart';
import 'package:touristmar_web/pages/business_edit_page.dart';
import 'package:touristmar_web/services/auth_service.dart';
import 'package:touristmar_web/services/recorridos_service.dart';
import 'package:touristmar_web/services/session_storage.dart';

BusinessProfile _negocio({double? latitud, double? longitud}) => BusinessProfile(
      id: 'n-1',
      businessName: 'Mariscos El Faro',
      ownerName: 'Ana',
      email: 'ana@faro.mx',
      category: 'Restaurante',
      description: 'Mariscos frescos.',
      coverImage: 'assets/images/place-playa-audiencia.jpg',
      gallery: const [],
      rating: 0,
      totalReviews: 0,
      monthlyVisits: 0,
      newReviews: 0,
      favorites: 0,
      phone: '3141234567',
      website: '',
      address: 'Av. Audiencia 12',
      hours: 'Lun a Dom 9:00 a 18:00',
      verified: true,
      estado: 'aprobado',
      latitud: latitud,
      longitud: longitud,
    );

void _ignorarCreditosDelMapa(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final onError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (!(d.toString().contains('flutter_map') && d.toString().contains('overflowed'))) onError?.call(d);
  };
  addTearDown(() => FlutterError.onError = onError);
}

/// Servidor falso: PATCH del negocio (lo regresa con lo enviado), estado del
/// recorrido ([estado]) y POST de la solicitud. Anota cada petición.
MockClient _servidor(List<String> peticiones, {Map<String, dynamic>? estado}) {
  return MockClient((request) async {
    peticiones.add('${request.method} ${request.url.path}');
    if (request.url.path.endsWith('/recorrido-360')) {
      return http.Response(jsonEncode(estado ?? {'tieneRecorrido': false, 'solicitud': null}), 200);
    }
    if (request.url.path.endsWith('/recorrido-360/solicitud')) {
      return http.Response(
        jsonEncode({
          'solicitud': {'id': 's-1', 'negocioId': 'n-1', 'estado': 'pendiente', 'createdAt': '2026-10-07T00:00:00.000Z'},
        }),
        201,
      );
    }
    final enviado = jsonDecode(request.body) as Map<String, dynamic>;
    return http.Response(
      jsonEncode({
        'user': {
          'id': 'u-1',
          'email': 'ana@faro.mx',
          'name': 'Ana',
          'role': 'negocio',
          'negocios': [
            {'id': 'n-1', 'estado': 'aprobado', 'galeria': [], 'createdAt': '2026-10-05T00:00:00.000Z', ...enviado},
          ],
        },
      }),
      200,
    );
  });
}

void main() {
  testWidgets('el negocio pega sus coordenadas junto a la dirección y se guardan', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Con la fuente de pruebas (Ahem) la franja de créditos de OpenStreetMap
    // del mini mapa no cabe; con la real sí. Solo se ignora ese aviso.
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      final creditos = d.toString().contains('flutter_map') && d.toString().contains('overflowed');
      if (!creditos) onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);
    SessionStorage.saveToken('jwt');

    Map<String, dynamic>? enviado;
    final client = MockClient((request) async {
      if (request.method != 'PATCH') return http.Response('{"tieneRecorrido":false,"solicitud":null}', 200);
      enviado = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'user': {
            'id': 'u-1',
            'email': 'ana@faro.mx',
            'name': 'Ana',
            'role': 'negocio',
            'negocios': [
              {'id': 'n-1', 'estado': 'aprobado', 'galeria': [], 'createdAt': '2026-10-05T00:00:00.000Z', ...enviado!},
            ],
          },
        }),
        200,
      );
    });

    final negocio = _negocio();
    await tester.pumpWidget(MaterialApp(home: BusinessEditPage(business: negocio, authService: AuthService(client: client))));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Ej. 19.1006, -104.3399'),
      '19.12492145230218, -104.40020700589847',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(enviado, containsPair('latitud', 19.12492145230218));
    expect(enviado, containsPair('longitud', -104.40020700589847));
    expect(enviado, containsPair('direccion', 'Av. Audiencia 12'));
    expect(negocio.latitud, 19.12492145230218);
  });

  testWidgets('si el negocio ya tiene pin, el campo lo muestra', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!(d.toString().contains('flutter_map') && d.toString().contains('overflowed'))) onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);

    await tester.pumpWidget(MaterialApp(home: BusinessEditPage(business: _negocio(latitud: 19.0675, longitud: -104.303))));
    await tester.pump();

    expect(find.text('19.0675, -104.303'), findsOneWidget);
  });

  group('solicitud de recorrido 360°', () {
    Future<void> montar(WidgetTester tester, BusinessProfile negocio, MockClient client) async {
      SessionStorage.saveToken('jwt');
      await tester.pumpWidget(MaterialApp(
        home: BusinessEditPage(
          business: negocio,
          authService: AuthService(client: client),
          recorridosService: RecorridosService(client: client),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('sin pin no se puede solicitar: pide marcar el negocio en el mapa', (tester) async {
      _ignorarCreditosDelMapa(tester);
      await montar(tester, _negocio(), _servidor([]));

      expect(find.text('Marca tu negocio en el mapa para poder solicitar su recorrido 360°.'), findsOneWidget);
      expect(find.textContaining('solicitar recorrido 360°'), findsNothing);
    });

    testWidgets('con el pin guardado aparece "Solicitar recorrido 360°" y envía la solicitud', (tester) async {
      _ignorarCreditosDelMapa(tester);
      final peticiones = <String>[];
      await montar(tester, _negocio(latitud: 19.0675, longitud: -104.303), _servidor(peticiones));

      await tester.ensureVisible(find.text('Solicitar recorrido 360°'));
      await tester.tap(find.text('Solicitar recorrido 360°'));
      await tester.pumpAndSettle();

      expect(peticiones, containsAllInOrder(['PATCH /api/auth/profile/negocios/n-1', 'POST /api/auth/profile/negocios/n-1/recorrido-360/solicitud']));
    });

    testWidgets('un pin nuevo sin guardar ofrece "Guardar y solicitar" y guarda antes de pedirlo', (tester) async {
      _ignorarCreditosDelMapa(tester);
      final peticiones = <String>[];
      final negocio = _negocio();
      await montar(tester, negocio, _servidor(peticiones));

      await tester.enterText(find.widgetWithText(TextField, 'Ej. 19.1006, -104.3399'), '19.12492145230218, -104.40020700589847');
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar y solicitar recorrido 360°'));
      await tester.tap(find.text('Guardar y solicitar recorrido 360°'));
      await tester.pumpAndSettle();

      final patch = peticiones.indexOf('PATCH /api/auth/profile/negocios/n-1');
      final post = peticiones.indexOf('POST /api/auth/profile/negocios/n-1/recorrido-360/solicitud');
      expect(patch, greaterThanOrEqualTo(0));
      expect(post, greaterThan(patch));
      expect(negocio.latitud, 19.12492145230218);
    });

    testWidgets('con una solicitud pendiente ya no muestra el botón', (tester) async {
      _ignorarCreditosDelMapa(tester);
      await montar(
        tester,
        _negocio(latitud: 19.0675, longitud: -104.303),
        _servidor([], estado: {
          'tieneRecorrido': false,
          'solicitud': {'id': 's-1', 'negocioId': 'n-1', 'estado': 'pendiente', 'createdAt': '2026-10-07T00:00:00.000Z'},
        }),
      );

      expect(find.textContaining('Solicitud enviada el'), findsOneWidget);
      expect(find.text('Solicitar recorrido 360°'), findsNothing);
    });

    testWidgets('si ya tiene recorrido no ofrece solicitarlo', (tester) async {
      _ignorarCreditosDelMapa(tester);
      await montar(tester, _negocio(latitud: 19.0675, longitud: -104.303), _servidor([], estado: {'tieneRecorrido': true}));

      expect(find.textContaining('ya cuenta con un recorrido 360°'), findsOneWidget);
      expect(find.text('Solicitar recorrido 360°'), findsNothing);
    });
  });
}
