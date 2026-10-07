// Pruebas del flujo "empresa solicita un negocio nuevo → el admin lo revisa".
//
// No necesitan backend: el servidor se reemplaza con un cliente HTTP falso
// (MockClient) y el selector de fotos con ImagePickerService.pick. Se corren
// con:
//
//   cd apps/web
//   flutter test test/solicitud_negocio_test.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/models/business_profile.dart';
import 'package:touristmar_web/pages/admin/admin_negocio_detalle_page.dart';
import 'package:touristmar_web/pages/admin/admin_requests_page.dart';
import 'package:touristmar_web/pages/business_suggest_page.dart';
import 'package:touristmar_web/services/auth_service.dart';
import 'package:touristmar_web/services/image_picker_service.dart';
import 'package:touristmar_web/services/session_storage.dart';
import 'package:touristmar_web/widgets/admin/admin_shell.dart';

// ── Datos de prueba ─────────────────────────────────────────────────────────

/// PNG válido de 1×1 px: la "foto" que elige el usuario en las pruebas.
final _fotoPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Map<String, dynamic> _negocioJson(String id, String nombre, {String estado = 'aprobado', String? portada}) => {
      'id': id,
      'nombre': nombre,
      'categoria': 'Restaurantes',
      'portada': portada,
      'galeria': <String>[],
      'estado': estado,
      'createdAt': '2026-09-01T00:00:00.000Z',
    };

/// Cuenta de empresa con su negocio aprobado y, si [conNuevo], el sugerido.
Map<String, dynamic> _empresa({bool conNuevo = false, String? portadaNuevo}) => {
      'id': 'u-1',
      'email': 'cafe@correo.com',
      'name': 'Ana',
      'role': 'negocio',
      'negocios': [
        _negocioJson('n-1', 'Café del Puerto'),
        if (conNuevo) _negocioJson('n-2', 'Mariscos La Bahía', estado: 'pendiente', portada: portadaNuevo),
      ],
    };

/// Detalle que devuelve GET /admin/negocios/n-2.
Map<String, dynamic> _detalle({String nombre = 'Mariscos La Bahía', String estado = 'pendiente'}) => {
      'id': 'n-2',
      'ownerId': 'u-1',
      'nombre': nombre,
      'categoria': 'Restaurantes',
      'descripcion': 'Mariscos frescos',
      'direccion': 'Malecón 12',
      'telefono': '314 000 0000',
      'sitioWeb': null,
      'horario': 'Lun–Dom 9:00–21:00',
      'portada': null,
      'galeria': <String>[],
      'latitud': 19.05432,
      'longitud': -104.31234,
      'estado': estado,
      'email': 'cafe@correo.com',
      'contacto': 'Ana',
      'solicitadoEn': '2026-10-01T00:00:00.000Z',
      'marcadores': [
        {'id': 'm-1', 'nombre': 'menu_bahia', 'titulo': 'Menú del día', 'activo': true},
      ],
      'recorridos': <Map<String, dynamic>>[],
    };

/// Petición anotada por el servidor falso.
class _Peticion {
  final String metodo;
  final String ruta;
  final String cuerpo;

  _Peticion(this.metodo, this.ruta, this.cuerpo);

  Map<String, dynamic> get json => jsonDecode(cuerpo) as Map<String, dynamic>;

  @override
  String toString() => '$metodo $ruta';
}

// ── Ayudas ──────────────────────────────────────────────────────────────────

/// Respuesta JSON en UTF-8, como la manda el backend real. `http.Response`
/// sin charset usa Latin-1 y truena con caracteres como "–" (guion largo).
http.Response _respuesta(String cuerpo, int status) => http.Response.bytes(
      utf8.encode(cuerpo),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void _pantallaCelular(WidgetTester tester, {double alto = 2400}) {
  tester.view.physicalSize = Size(430, alto);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void _simularFotoElegida() {
  final original = ImagePickerService.pick;
  ImagePickerService.pick = () async => PickedImage(_fotoPng, 'portada.png');
  addTearDown(() => ImagePickerService.pick = original);
}

/// Pantalla mínima con un botón "Abrir" que empuja la página y guarda lo que
/// devuelve al cerrarse.
Widget _anfitrion(Widget Function() pagina, void Function(Object?) alCerrar) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => alCerrar(await Navigator.of(context).push<Object?>(MaterialPageRoute(builder: (_) => pagina()))),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _campo(String etiqueta) => find.descendant(
      of: find.ancestor(of: find.text(etiqueta), matching: find.byType(Column)).first,
      matching: find.byType(TextFormField),
    );

void main() {
  setUp(() => SessionStorage.saveToken('token-prueba'));
  tearDown(SessionStorage.clearToken);

  group('Servicio', () {
    test('la sugerencia manda imagen aparte y ubicación, teléfono y horario en el cuerpo', () async {
      final peticiones = <_Peticion>[];
      final service = AuthService(
        client: MockClient((r) async {
          peticiones.add(_Peticion(r.method, r.url.path, r.body));
          return _respuesta(jsonEncode({'user': _empresa(conNuevo: true)}), 201);
        }),
      );

      await service.createNegocioSuggestion(
        'token',
        nombre: 'Mariscos La Bahía',
        categoria: 'Restaurantes',
        telefono: '314 000 0000',
        horario: 'Lun–Dom',
        latitud: 19.05,
        longitud: -104.31,
      );

      expect(peticiones.single.ruta, '/api/auth/profile/negocios');
      final cuerpo = peticiones.single.json;
      expect(cuerpo['telefono'], '314 000 0000');
      expect(cuerpo['horario'], 'Lun–Dom');
      expect(cuerpo['latitud'], 19.05);
      expect(cuerpo['longitud'], -104.31);
      // Campos vacíos no se mandan.
      expect(cuerpo.containsKey('direccion'), isFalse);
    });

    test('el detalle admin trae datos, ubicación y contenido de RA ligado', () async {
      final service = AuthService(
        client: MockClient((r) async => _respuesta(jsonEncode({'negocio': _detalle()}), 200)),
      );
      final n = await service.adminGetNegocio('token', 'n-2');
      expect(n.nombre, 'Mariscos La Bahía');
      expect(n.tieneUbicacion, isTrue);
      expect(n.marcadores.single.titulo, 'Menú del día');
      expect(n.pendiente, isTrue);
    });

    test('las notificaciones de solicitud llevan a "Solicitudes"', () {
      expect(adminSectionForNotification('negocio_sugerido'), AdminSection.solicitudes);
      expect(adminSectionForNotification('negocio_pendiente'), AdminSection.solicitudes);
    });
  });

  testWidgets('Empresa: el formulario envía la solicitud con imagen de portada', (tester) async {
    _pantallaCelular(tester);
    _simularFotoElegida();
    final peticiones = <_Peticion>[];
    final service = AuthService(
      client: MockClient((r) async {
        final subioPortada = r.url.path.endsWith('/avatar');
        // La portada va como multipart (bytes de imagen): no se decodifica.
        peticiones.add(_Peticion(r.method, r.url.path, subioPortada ? '' : r.body));
        return _respuesta(
          jsonEncode({'user': _empresa(conNuevo: true, portadaNuevo: subioPortada ? 'https://cdn/portada.png' : null)}),
          200,
        );
      }),
    );
    Object? devuelto;
    await tester.pumpWidget(_anfitrion(() => BusinessSuggestPage(authService: service), (r) => devuelto = r));
    await _tocar(tester, find.text('Abrir'));

    // Imagen, nombre y categoría.
    await _tocar(tester, find.text('Elegir imagen'));
    expect(find.text('Elegir imagen'), findsNothing, reason: 'se ve la vista previa');
    await tester.enterText(_campo('Nombre del negocio'), 'Mariscos La Bahía');
    await tester.enterText(_campo('Categoría'), 'Restaurantes');
    await tester.enterText(_campo('Teléfono (opcional)'), '314 000 0000');
    expect(find.text('Sin ubicación marcada'), findsOneWidget);
    expect(find.text('Elegir en el mapa'), findsOneWidget);

    await _tocar(tester, find.text('Enviar sugerencia'));

    expect(peticiones.map((p) => p.toString()).toList(), [
      'POST /api/auth/profile/negocios',
      'POST /api/auth/profile/negocios/n-2/avatar',
    ]);
    expect(peticiones.first.json['telefono'], '314 000 0000');
    expect(find.byType(BusinessSuggestPage), findsNothing);
    expect(devuelto, isA<BusinessProfile>());
    expect((devuelto! as BusinessProfile).id, 'n-2');
  });

  group('Admin: detalle de la solicitud', () {
    late List<_Peticion> peticiones;
    late AuthService service;

    setUp(() {
      peticiones = [];
      service = AuthService(
        client: MockClient((r) async {
          final body = r.body;
          peticiones.add(_Peticion(r.method, r.url.path, body));
          if (r.method == 'PATCH') {
            final cambios = jsonDecode(body) as Map<String, dynamic>;
            return _respuesta(jsonEncode({'negocio': _detalle(nombre: cambios['nombre'] as String)}), 200);
          }
          if (r.url.path.endsWith('/aprobar') || r.url.path.endsWith('/rechazar')) {
            return _respuesta('{}', 200);
          }
          return _respuesta(jsonEncode({'negocio': _detalle()}), 200);
        }),
      );
    });

    testWidgets('muestra imagen, título, ubicación y el contenido de RA', (tester) async {
      _pantallaCelular(tester);
      await tester.pumpWidget(MaterialApp(home: AdminNegocioDetallePage(negocioId: 'n-2', authService: service)));
      await tester.pumpAndSettle();

      expect(peticiones.single.toString(), 'GET /api/admin/negocios/n-2');
      expect(find.text('Mariscos La Bahía'), findsWidgets);
      expect(find.text('Imagen de portada'), findsOneWidget);
      expect(find.text('19.05432, -104.31234'), findsOneWidget);
      expect(find.text('Menú del día · menu_bahia'), findsOneWidget);
      expect(find.text('Añadir RA por marcador'), findsOneWidget);
      expect(find.text('Añadir recorrido 360°'), findsOneWidget);
      expect(find.text('Aprobar'), findsOneWidget);
    });

    testWidgets('el admin edita los datos y los guarda', (tester) async {
      _pantallaCelular(tester);
      await tester.pumpWidget(MaterialApp(home: AdminNegocioDetallePage(negocioId: 'n-2', authService: service)));
      await tester.pumpAndSettle();

      await tester.enterText(_campo('Nombre del negocio'), 'Mariscos La Bahía Centro');
      await tester.pump();
      await _tocar(tester, find.text('Guardar cambios'));

      final patch = peticiones.firstWhere((p) => p.metodo == 'PATCH');
      expect(patch.ruta, '/api/admin/negocios/n-2');
      expect(patch.json['nombre'], 'Mariscos La Bahía Centro');
      expect(patch.json['latitud'], 19.05432);
      expect(find.text('Cambios guardados.'), findsOneWidget);
    });

    testWidgets('"Guardar y aprobar" guarda los cambios antes de aprobar', (tester) async {
      _pantallaCelular(tester);
      Object? devuelto;
      await tester.pumpWidget(
        _anfitrion(() => AdminNegocioDetallePage(negocioId: 'n-2', authService: service), (r) => devuelto = r),
      );
      await _tocar(tester, find.text('Abrir'));

      await tester.enterText(_campo('Horario'), 'Lun–Sáb 10:00–20:00');
      await tester.pump();
      await _tocar(tester, find.text('Guardar y aprobar'));

      expect(peticiones.map((p) => p.toString()).toList(), [
        'GET /api/admin/negocios/n-2',
        'PATCH /api/admin/negocios/n-2',
        'POST /api/admin/negocios/n-2/aprobar',
      ]);
      expect(devuelto, isA<ResultadoDetalleNegocio>());
      expect((devuelto! as ResultadoDetalleNegocio).aprobado, isTrue);
    });

    testWidgets('"Añadir RA por marcador" regresa pidiendo abrir esa sección', (tester) async {
      _pantallaCelular(tester);
      Object? devuelto;
      await tester.pumpWidget(
        _anfitrion(() => AdminNegocioDetallePage(negocioId: 'n-2', authService: service), (r) => devuelto = r),
      );
      await _tocar(tester, find.text('Abrir'));
      await _tocar(tester, find.text('Añadir RA por marcador'));

      final r = devuelto! as ResultadoDetalleNegocio;
      expect(r.negocioId, 'n-2');
      expect(r.abrirContenido, ContenidoNegocio.realidadAumentada);
      expect(r.aprobado, isNull);
    });
  });

  testWidgets('Admin: "Ver y editar" en Solicitudes abre el detalle', (tester) async {
    _pantallaCelular(tester);
    final service = AuthService(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/pendientes')) {
          return _respuesta(
            jsonEncode({
              'negocios': [
                {
                  'id': 'n-2',
                  'ownerId': 'u-1',
                  'nombre': 'Mariscos La Bahía',
                  'categoria': 'Restaurantes',
                  'email': 'cafe@correo.com',
                  'contacto': 'Ana',
                  'solicitadoEn': '2026-10-01T00:00:00.000Z',
                  'latitud': 19.05,
                  'longitud': -104.31,
                  'esAdicional': true,
                },
              ],
            }),
            200,
          );
        }
        return _respuesta(jsonEncode({'negocio': _detalle()}), 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminRequestsPage(authService: service))));
    await tester.pumpAndSettle();

    expect(find.text('Con ubicación'), findsOneWidget);
    await _tocar(tester, find.text('Ver y editar'));
    expect(find.byType(AdminNegocioDetallePage), findsOneWidget);
    expect(find.text('Solicitud de negocio'), findsOneWidget);
  });
}
