// Pruebas de las correcciones reportadas en "Errores.docx".
//
// No necesitan backend, base de datos ni celular: el servidor se reemplaza con
// un cliente HTTP falso (MockClient) y el selector de fotos con
// ImagePickerService.pick. Se corren con:
//
//   cd apps/web
//   flutter test test/correcciones_errores_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touristmar_web/navegacion/rutas.dart';
import 'package:touristmar_web/navegacion/sesion.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/models/business_profile.dart';
import 'package:touristmar_web/models/visitor_profile.dart';
import 'package:touristmar_web/pages/business_edit_page.dart';
import 'package:touristmar_web/pages/business_gallery_page.dart';
import 'package:touristmar_web/pages/edit_profile_page.dart';
import 'package:touristmar_web/pages/home_page.dart';
import 'package:touristmar_web/services/auth_service.dart';
import 'package:touristmar_web/services/image_picker_service.dart';
import 'package:touristmar_web/services/session_storage.dart';
import 'package:touristmar_web/theme/theme_controller.dart';
import 'package:touristmar_web/widgets/favorito_button.dart' show colorFavorito;
import 'package:touristmar_web/widgets/login_form.dart';
import 'package:touristmar_web/widgets/notification_bell.dart';
import 'package:touristmar_web/widgets/place_card.dart';
import 'package:touristmar_web/widgets/user_avatar.dart';

// ── Datos de prueba ─────────────────────────────────────────────────────────

/// PNG válido de 1×1 px: la "foto" que elige el usuario en las pruebas.
final _fotoPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

const _turista = AuthUser(id: '1', email: 'ana@correo.com', name: 'Ana', role: 'turista');

const _portadaOriginal = 'assets/images/place-playa-audiencia.jpg';
const _fotoGaleria1 = 'assets/images/place-cerro-vigia.jpg';
const _fotoGaleria2 = 'assets/images/place-laguna-cuyutlan.jpg';

BusinessProfile _negocio({List<String> gallery = const []}) => BusinessProfile(
      id: 'n-1',
      businessName: 'Café del Puerto',
      ownerName: 'Ana',
      email: 'cafe@correo.com',
      category: 'Restaurantes',
      description: 'Mariscos frente al mar',
      coverImage: _portadaOriginal,
      gallery: [...gallery],
      rating: 0,
      totalReviews: 0,
      monthlyVisits: 0,
      newReviews: 0,
      favorites: 0,
      phone: '314 123 4567',
      website: '',
      address: 'Av. Principal 1',
      hours: 'Lun a Dom 9:00 a 18:00',
      verified: true,
      estado: 'aprobado',
    );

/// Respuesta del backend con la cuenta de negocio actualizada.
Map<String, dynamic> _usuarioNegocio({String? portada, List<String> galeria = const []}) => {
      'id': '1',
      'email': 'cafe@correo.com',
      'name': 'Ana',
      'role': 'negocio',
      'negocios': [
        {
          'id': 'n-1',
          'nombre': 'Café del Puerto',
          'categoria': 'Restaurantes',
          'descripcion': 'Mariscos frente al mar',
          'direccion': 'Av. Principal 1',
          'telefono': '314 123 4567',
          'horario': 'Lun a Dom 9:00 a 18:00',
          'portada': portada,
          'galeria': galeria,
          'estado': 'aprobado',
          'createdAt': '2026-09-01T00:00:00.000Z',
        },
      ],
    };

/// Servidor falso: anota cada petición ("POST /ruta") y responde con [user].
MockClient _servidorFalso(List<String> peticiones, Map<String, dynamic> user) {
  return MockClient((request) async {
    peticiones.add('${request.method} ${request.url.path}');
    return http.Response(jsonEncode({'user': user}), 200);
  });
}

// ── Ayudas ──────────────────────────────────────────────────────────────────

void _pantallaCelular(WidgetTester tester, {double alto = 1600}) {
  tester.view.physicalSize = Size(430, alto);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Simula que el usuario elige [_fotoPng] en el selector de imágenes.
void _simularFotoElegida() {
  final original = ImagePickerService.pick;
  ImagePickerService.pick = () async => PickedImage(_fotoPng, 'nueva.png');
  addTearDown(() => ImagePickerService.pick = original);
}

/// Pantalla mínima con un botón "Abrir" que empuja [pagina], como hace la
/// app real desde "Mi perfil" / "Mi negocio".
Widget _anfitrion(Widget Function() pagina) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina())),
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

/// Desmonta todo para cancelar los temporizadores (campana de notificaciones).
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

bool _buscadorTieneFoco(WidgetTester tester) {
  return tester.widget<EditableText>(find.byType(EditableText).first).focusNode.hasFocus;
}

/// "Editar negocio" siempre muestra el mapa para marcar el pin. Con la
/// fuente de pruebas (Ahem) la franja de créditos de OpenStreetMap no cabe;
/// con la real sí. Solo se ignora ese aviso.
void _ignorarCreditosDelMapa() {
  final onError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (!(d.toString().contains('flutter_map') && d.toString().contains('overflowed'))) onError?.call(d);
  };
  addTearDown(() => FlutterError.onError = onError);
}

void main() {
  setUp(SessionStorage.clearToken);

  group('Error 1 — "¿Te gustaría registrar un lugar nuevo?"', () {
    testWidgets('el banner lleva al registro de negocio', (tester) async {
      _pantallaCelular(tester);
      // La app con sus rutas: cerrar sesión lleva a /login?registro=negocio.
      Sesion.iniciar(_turista);
      addTearDown(reiniciarSesionParaPruebas);
      final router = crearRouter(inicial: '/inicio');
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      // La sesión se guarda después de montar la pantalla para que la campana
      // no intente consultar notificaciones a un servidor real.
      SessionStorage.saveToken('token-turista');

      await _tocar(tester, find.text('¿Te gustaría registrar un lugar nuevo?'));
      expect(find.text('Registrar un lugar nuevo'), findsOneWidget);

      await _tocar(tester, find.text('Continuar'));

      // Se cerró la sesión de visitante y se abrió el registro de negocio.
      expect(SessionStorage.token, isNull);
      expect(find.byType(HomePage), findsNothing);
      expect(find.byType(LoginForm), findsOneWidget);
      expect(find.byKey(const ValueKey('category-field')), findsOneWidget);
      expect(find.text('Solicitar registro'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/login?registro=negocio');
      await _desmontar(tester);
    });

    testWidgets('"Proponer lugar" abre el mismo aviso y "Cancelar" no cierra la sesión', (tester) async {
      _pantallaCelular(tester);
      await tester.pumpWidget(const MaterialApp(home: HomePage(user: _turista)));
      await tester.pump();
      // La sesión se guarda después de montar la pantalla para que la campana
      // no intente consultar notificaciones a un servidor real.
      SessionStorage.saveToken('token-turista');

      await _tocar(tester, find.text('Proponer lugar'));
      expect(find.text('Registrar un lugar nuevo'), findsOneWidget);

      await _tocar(tester, find.text('Cancelar'));
      expect(find.byType(HomePage), findsOneWidget);
      expect(SessionStorage.token, 'token-turista');
      await _desmontar(tester);
    });
  });

  testWidgets('Error 2 — abrir y cerrar el menú lateral no despliega el teclado', (tester) async {
    _pantallaCelular(tester, alto: 900);
    await tester.pumpWidget(const MaterialApp(home: HomePage(user: _turista)));
    await tester.pump();

    // El usuario escribe en la búsqueda: el teclado aparece.
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(_buscadorTieneFoco(tester), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    // Abre el menú lateral (botón del avatar).
    await tester.tap(find.byType(UserAvatar).first);
    await tester.pumpAndSettle();
    expect(_buscadorTieneFoco(tester), isFalse);
    expect(tester.testTextInput.isVisible, isFalse);

    // Lo cierra: el teclado NO debe volver a abrirse solo.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(_buscadorTieneFoco(tester), isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    await _desmontar(tester);
  });

  testWidgets('Error 3 — la barra superior queda debajo de la barra de estado del teléfono', (tester) async {
    _pantallaCelular(tester, alto: 900);
    // Barra de estado de 48 px, como la de un Android con notch.
    tester.view.padding = const FakeViewPadding(top: 48);
    tester.view.viewPadding = const FakeViewPadding(top: 48);

    await tester.pumpWidget(const MaterialApp(home: HomePage(user: _turista)));
    await tester.pump();

    expect(tester.getTopLeft(find.byType(NotificationBell)).dy, greaterThanOrEqualTo(48));
    expect(tester.getTopLeft(find.byType(UserAvatar).first).dy, greaterThanOrEqualTo(48));
    await _desmontar(tester);
  });

  group('Errores 4, 5 y 5.2 — foto de perfil', () {
    testWidgets('una foto elegida y cancelada no se sube ni se aplica, ni al cambiar de tema', (tester) async {
      _pantallaCelular(tester);
      _simularFotoElegida();
      final peticiones = <String>[];
      final perfil = VisitorProfile(name: 'Ana', email: 'ana@correo.com');
      final servicio = AuthService(client: _servidorFalso(peticiones, {}));

      await tester.pumpWidget(_anfitrion(() => EditProfilePage(profile: perfil, authService: servicio)));
      await _tocar(tester, find.text('Abrir'));
      await _tocar(tester, find.text('Cambiar foto'));
      expect(find.text('Vista previa — se aplicará al guardar'), findsOneWidget);

      // Error 5: cambiar de tema con la foto sin guardar no la aplica.
      ThemeController.toggle();
      await tester.pump();
      ThemeController.toggle();
      await tester.pump();
      expect(perfil.avatarUrl, isNull);

      await _tocar(tester, find.text('Cancelar'));
      expect(perfil.avatarUrl, isNull);
      expect(peticiones, isEmpty, reason: 'Nada debe subirse al servidor si se cancela');

      // Error 4: al volver a "Editar perfil" ya no aparece la foto descartada.
      await _tocar(tester, find.text('Abrir'));
      expect(find.text('Vista previa — se aplicará al guardar'), findsNothing);
    });

    testWidgets('al tocar "Guardar cambios" sí se sube y se aplica', (tester) async {
      _pantallaCelular(tester);
      _simularFotoElegida();
      SessionStorage.saveToken('jwt');
      final peticiones = <String>[];
      final perfil = VisitorProfile(name: 'Ana', email: 'ana@correo.com');
      final servicio = AuthService(
        client: _servidorFalso(peticiones, {
          'id': '1',
          'email': 'ana@correo.com',
          'name': 'Ana',
          'role': 'turista',
          'avatarUrl': 'https://cdn.test/nueva.png',
        }),
      );

      await tester.pumpWidget(_anfitrion(() => EditProfilePage(profile: perfil, authService: servicio)));
      await _tocar(tester, find.text('Abrir'));
      await _tocar(tester, find.text('Cambiar foto'));
      await _tocar(tester, find.text('Guardar cambios'));

      expect(peticiones.where((p) => p.startsWith('POST') && p.endsWith('/auth/profile/avatar')), hasLength(1));
      expect(perfil.avatarUrl, 'https://cdn.test/nueva.png');
      expect(find.text('Abrir'), findsOneWidget, reason: 'La pantalla de edición se cierra al guardar');
    });
  });

  testWidgets('Foto de perfil nueva — al volver al inicio ya se ve, sin recargar la página', (tester) async {
    _pantallaCelular(tester);
    // La foto es una URL de prueba que no existe; solo importa cuál se pide.
    final onError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.library != 'image resource service') onError?.call(d);
    };
    addTearDown(() => FlutterError.onError = onError);
    Sesion.iniciar(_turista);
    addTearDown(reiniciarSesionParaPruebas);

    // Lo que hace "Editar perfil" al guardar: actualiza el perfil de la sesión.
    Sesion.perfilVisitante.avatarUrl = 'https://cdn.test/nueva.png';
    Sesion.perfilVisitante.name = 'Lucía Pérez';

    // El usuario regresa al inicio (la pantalla se vuelve a crear con el
    // usuario que trajo el login, que todavía tiene la foto vieja).
    await tester.pumpWidget(const MaterialApp(home: HomePage(user: _turista)));
    await tester.pump();

    expect(tester.widget<UserAvatar>(find.byType(UserAvatar).first).imageUrl, 'https://cdn.test/nueva.png');
    expect(find.textContaining('Lucía'), findsWidgets);
    await _desmontar(tester);
  });

  group('Error 5.3 — portada del negocio (modo empresario)', () {
    testWidgets('una portada elegida y cancelada no se sube ni se aplica', (tester) async {
      _pantallaCelular(tester);
      _ignorarCreditosDelMapa();
      _simularFotoElegida();
      final peticiones = <String>[];
      final negocio = _negocio();
      final servicio = AuthService(client: _servidorFalso(peticiones, _usuarioNegocio()));

      await tester.pumpWidget(_anfitrion(() => BusinessEditPage(business: negocio, authService: servicio)));
      await _tocar(tester, find.text('Abrir'));
      await _tocar(tester, find.text('Cambiar foto de portada'));
      expect(find.text('Vista previa — se aplicará al guardar'), findsOneWidget);

      await _tocar(tester, find.text('Cancelar'));
      expect(negocio.coverImage, _portadaOriginal);
      expect(peticiones, isEmpty);
    });

    testWidgets('al guardar se sube la portada junto con los datos', (tester) async {
      _pantallaCelular(tester);
      _ignorarCreditosDelMapa();
      _simularFotoElegida();
      SessionStorage.saveToken('jwt');
      final peticiones = <String>[];
      final negocio = _negocio();
      final servicio = AuthService(client: _servidorFalso(peticiones, _usuarioNegocio(portada: _fotoGaleria1)));

      await tester.pumpWidget(_anfitrion(() => BusinessEditPage(business: negocio, authService: servicio)));
      await _tocar(tester, find.text('Abrir'));
      await _tocar(tester, find.text('Cambiar foto de portada'));
      await _tocar(tester, find.text('Guardar cambios'));

      expect(peticiones.where((p) => p.startsWith('POST') && p.endsWith('/negocios/n-1/avatar')), hasLength(1));
      expect(peticiones.where((p) => p.startsWith('PATCH') && p.endsWith('/negocios/n-1')), hasLength(1));
      expect(negocio.coverImage, _fotoGaleria1);
    });
  });

  group('Error 5.4 — galería del local', () {
    testWidgets('agregar o quitar fotos y salir sin guardar no cambia nada', (tester) async {
      _pantallaCelular(tester);
      _simularFotoElegida();
      final peticiones = <String>[];
      final negocio = _negocio(gallery: [_fotoGaleria1]);
      final servicio = AuthService(client: _servidorFalso(peticiones, _usuarioNegocio()));

      await tester.pumpWidget(_anfitrion(() => BusinessGalleryPage(business: negocio, authService: servicio)));
      await _tocar(tester, find.text('Abrir'));

      await _tocar(tester, find.text('Agregar'));
      expect(find.text('Sin guardar'), findsOneWidget);

      // También quita la foto que ya estaba guardada.
      await _tocar(tester, find.byIcon(Icons.close).first);

      await _tocar(tester, find.text('Cancelar'));
      expect(find.text('Descartar cambios'), findsOneWidget, reason: 'Pide confirmación antes de descartar');
      await _tocar(tester, find.text('Descartar'));

      expect(find.text('Abrir'), findsOneWidget);
      expect(negocio.gallery, [_fotoGaleria1]);
      expect(peticiones, isEmpty, reason: 'No se sube ni se borra nada sin guardar');
    });

    testWidgets('al tocar "Guardar cambios" se sube la foto nueva', (tester) async {
      _pantallaCelular(tester);
      _simularFotoElegida();
      SessionStorage.saveToken('jwt');
      final peticiones = <String>[];
      final negocio = _negocio(gallery: [_fotoGaleria1]);
      final servicio = AuthService(
        client: _servidorFalso(peticiones, _usuarioNegocio(galeria: [_fotoGaleria1, _fotoGaleria2])),
      );

      await tester.pumpWidget(_anfitrion(() => BusinessGalleryPage(business: negocio, authService: servicio)));
      await _tocar(tester, find.text('Abrir'));
      await _tocar(tester, find.text('Agregar'));
      await _tocar(tester, find.text('Guardar cambios'));

      expect(peticiones.where((p) => p.startsWith('POST') && p.endsWith('/negocios/n-1/galeria')), hasLength(1));
      expect(negocio.gallery, [_fotoGaleria1, _fotoGaleria2]);
      expect(find.text('Abrir'), findsOneWidget);
    });
  });

  testWidgets('Punto a verificar — el corazón de favoritos se ve rojo al estar guardado', (tester) async {
    final temaOriginal = ThemeController.mode.value;
    ThemeController.set(ThemeMode.light);
    addTearDown(() => ThemeController.set(temaOriginal));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: PlaceCard(
              image: _fotoGaleria1,
              category: 'Miradores',
              name: 'Cerro del Vigía',
              rating: 4.8,
              isFavorite: true,
            ),
          ),
        ),
      ),
    );

    final corazon = tester.widget<Icon>(find.byIcon(Icons.favorite));
    expect(corazon.color, colorFavorito);
  });
}
