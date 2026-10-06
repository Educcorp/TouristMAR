import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/models/business_profile.dart';
import 'package:touristmar_web/pages/business_edit_page.dart';
import 'package:touristmar_web/services/auth_service.dart';
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
}
