import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/navegacion/rutas.dart';
import 'package:touristmar_web/navegacion/sesion.dart';
import 'package:touristmar_web/services/auth_service.dart';
import 'package:touristmar_web/services/session_storage.dart';

const _admin = AuthUser(id: 'a-1', email: 'admin@touristmar.mx', name: 'Admin', role: 'admin');

Map<String, dynamic> _fime() => {
      'id': 'n-fime',
      'nombre': 'Facultad de Ingeniería Electromecánica',
      'categoria': 'Cultura y educación',
      'direccion': 'Campus El Naranjo',
      'estado': 'aprobado',
      'email': 'super@touristmar.mx',
      'contacto': 'Super',
      'solicitadoEn': '2026-10-06T00:00:00.000Z',
      'latitud': 19.12492145230218,
      'longitud': -104.40020700589847,
    };

void main() {
  late List<Map<String, dynamic>> creados;

  MockClient servidor() => MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/admin/negocios')) {
          return http.Response(jsonEncode({'negocios': [_fime(), ...creados]}), 200);
        }
        if (request.method == 'POST' && request.url.path.endsWith('/admin/lugares')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final nuevo = {
            'id': 'n-${creados.length + 2}',
            ...body,
            'estado': 'aprobado',
            'email': 'super@touristmar.mx',
            'contacto': 'Super',
            'solicitadoEn': '2026-10-06T00:00:00.000Z',
          };
          creados.add(nuevo);
          return http.Response(jsonEncode({'negocio': nuevo}), 201);
        }
        return http.Response('{}', 404);
      });

  Future<GoRouter> montar(WidgetTester tester, String ruta) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      // Créditos de OpenStreetMap de los mapas con la fuente de pruebas (Ahem).
      if (!(d.toString().contains('flutter_map') && d.toString().contains('overflowed'))) onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);
    final router = crearRouter(authService: AuthService(client: servidor()), inicial: ruta);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> desmontar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  setUp(() {
    creados = [];
    reiniciarSesionParaPruebas();
    Sesion.iniciar(_admin);
    SessionStorage.saveToken('jwt');
  });

  testWidgets('el admin registra un lugar con sus coordenadas desde "Registrar lugar"', (tester) async {
    await montar(tester, '/admin/mapa');

    // El formulario está oculto hasta tocar el botón.
    expect(find.text('Nombre del lugar'), findsNothing);
    await tester.tap(find.text('Registrar lugar').first);
    await tester.pumpAndSettle();
    expect(find.text('Nombre del lugar'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Ej. Playa La Audiencia'), 'Mirador del Vigía');
    await tester.tap(find.text('Mirador'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Ej. 19.1006, -104.3399'),
      '19.0548, -104.3204',
    );
    // La vista previa del pin agranda la sección con una animación.
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Registrar lugar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar lugar').last);
    await tester.pumpAndSettle();

    expect(creados.single, containsPair('nombre', 'Mirador del Vigía'));
    expect(creados.single, containsPair('categoria', 'Mirador'));
    expect(creados.single, containsPair('latitud', 19.0548));
    // Aparece en la lista de lugares.
    expect(find.text('Mirador del Vigía'), findsWidgets);
    await desmontar(tester);
  });

  testWidgets('"Revisar" abre la página del lugar con su URL y sus tres secciones desplegables', (tester) async {
    final router = await montar(tester, '/admin/mapa');

    await tester.tap(find.text('Revisar').first);
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/admin/mapa/lugar/n-fime');
    expect(find.text('Realidad aumentada por ubicación'), findsOneWidget);
    expect(find.text('Recorrido 3D / 360°'), findsOneWidget);
    expect(find.text('Realidad aumentada con marcador'), findsOneWidget);

    // RA por ubicación: se despliega con la flecha y trae las coordenadas del lugar.
    await tester.tap(find.text('Realidad aumentada por ubicación'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '19.12492145230218, -104.40020700589847'),
      findsOneWidget,
    );

    // La flecha "Mapa y RA" regresa a la lista.
    await tester.tap(find.widgetWithText(TextButton, 'Mapa y RA'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/admin/mapa');
    await desmontar(tester);
  });
}
