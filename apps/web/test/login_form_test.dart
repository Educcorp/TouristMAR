// Usa dart:html (SessionStorage, redirect de Google), así que solo corre en
// navegador: `flutter test --platform chrome` (ver `npm test` en la raíz).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/main.dart' show TouristMarApp;
import 'package:touristmar_web/navegacion/sesion.dart';
import 'package:touristmar_web/pages/admin/admin_dashboard_page.dart';
import 'package:touristmar_web/pages/business_home_page.dart';
import 'package:touristmar_web/pages/home_page.dart';
import 'package:touristmar_web/services/auth_service.dart';
import 'package:touristmar_web/services/session_storage.dart';
import 'package:touristmar_web/widgets/login_form.dart';

/// Contraseña que cumple las reglas para crear cuenta (lib/utils/password_strength.dart:
/// 8+ caracteres, un carácter especial, no común ni secuencia). Úsala en
/// toda prueba de REGISTRO; si las reglas cambian, se cambia solo aquí.
const _contrasenaSegura = 'Faro#Manzanillo26';

/// Contraseña vieja y débil: el LOGIN la sigue aceptando (las cuentas que se
/// crearon antes de las reglas nuevas deben poder entrar).
const _contrasenaExistente = 'password123';

Map<String, dynamic> _negocio({String estado = 'pendiente', String nombre = 'Café del Puerto'}) => {
      'id': 'n-1',
      'nombre': nombre,
      'categoria': 'Restaurantes',
      'estado': estado,
      'createdAt': '2026-09-01T00:00:00.000Z',
    };

Map<String, dynamic> _user({
  String id = '1',
  String email = 'ana@correo.com',
  String name = 'Ana',
  String role = 'turista',
  List<Map<String, dynamic>> negocios = const [],
}) =>
    {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'avatarUrl': null,
      'negocios': negocios,
    };

/// Cliente falso que responde login/register con [user] y guarda los
/// cuerpos enviados para poder revisarlos.
MockClient _authClient(Map<String, dynamic> user, {List<Map<String, dynamic>>? bodies}) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/auth/login') || request.url.path.endsWith('/auth/register')) {
      bodies?.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({'token': 'jwt-token', 'user': user}), 200);
    }
    return http.Response('{}', 404);
  });
}

Future<void> _pumpLoginForm(WidgetTester tester, AuthService authService) async {
  // Pantalla de escritorio: con el tamaño por defecto (800×600) los botones
  // del formulario quedan fuera de la vista y los taps no les llegan.
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // La app completa con sus rutas: así se prueba también a dónde lleva
  // cada rol después de entrar.
  await tester.pumpWidget(TouristMarApp(authService: authService, rutaInicial: '/login'));
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

Future<void> _submitLogin(WidgetTester tester, {String password = _contrasenaExistente}) async {
  await tester.enterText(find.byKey(const ValueKey('email-field')), 'ana@correo.com');
  await tester.enterText(find.byKey(const ValueKey('password-field')), password);
  await _tapText(tester, 'Iniciar sesión');
}

/// Deja que termine la transición de `pushReplacement`. No se usa
/// `pumpAndSettle` porque las pantallas de destino (campana de
/// notificaciones, SessionGuard) arrancan temporizadores periódicos.
Future<void> _pumpNavigation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Desmonta el árbol para cancelar los temporizadores de la pantalla de
/// destino antes de que el test termine.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SessionStorage.clearToken();
    reiniciarSesionParaPruebas();
  });

  testWidgets('un turista inicia sesión, se guarda el token y entra al inicio de visitante', (tester) async {
    await _pumpLoginForm(tester, AuthService(client: _authClient(_user())));

    await _submitLogin(tester);
    await _pumpNavigation(tester);

    expect(SessionStorage.token, 'jwt-token');
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginForm), findsNothing);
    await _disposeTree(tester);
  });

  testWidgets('un admin entra al panel de administración', (tester) async {
    await _pumpLoginForm(tester, AuthService(client: _authClient(_user(role: 'admin'))));

    await _submitLogin(tester);
    await _pumpNavigation(tester);

    expect(find.byType(AdminDashboardPage), findsOneWidget);
    await _disposeTree(tester);
  });

  testWidgets('un negocio con al menos un negocio aprobado entra a su panel', (tester) async {
    final user = _user(role: 'negocio', negocios: [_negocio(estado: 'aprobado')]);
    await _pumpLoginForm(tester, AuthService(client: _authClient(user)));

    await _submitLogin(tester);
    await _pumpNavigation(tester);

    expect(find.byType(BusinessHomePage), findsOneWidget);
    await _disposeTree(tester);
  });

  testWidgets('un negocio pendiente no entra al panel: ve su estado y puede cerrar sesión', (tester) async {
    final user = _user(role: 'negocio', negocios: [_negocio()]);
    await _pumpLoginForm(tester, AuthService(client: _authClient(user)));

    await _submitLogin(tester);
    await tester.pumpAndSettle();

    expect(find.byType(BusinessHomePage), findsNothing);
    expect(find.text('Tu negocio está en revisión'), findsOneWidget);
    expect(find.text('Café del Puerto'), findsOneWidget);

    await _tapText(tester, 'Cerrar sesión');
    await tester.pumpAndSettle();

    expect(SessionStorage.token, isNull);
    expect(find.byKey(const ValueKey('email-field')), findsOneWidget);
  });

  testWidgets('un negocio rechazado ve el aviso de registro no aprobado', (tester) async {
    final user = _user(role: 'negocio', negocios: [_negocio(estado: 'rechazado')]);
    await _pumpLoginForm(tester, AuthService(client: _authClient(user)));

    await _submitLogin(tester);
    await tester.pumpAndSettle();

    expect(find.text('Registro no aprobado'), findsOneWidget);
  });

  testWidgets('muestra un error inline cuando el login falla', (tester) async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'error': 'Correo o contraseña incorrectos'}), 401);
    });
    await _pumpLoginForm(tester, AuthService(client: client));

    await _submitLogin(tester, password: 'incorrecta');
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
    expect(find.byType(LoginForm), findsOneWidget);
    expect(SessionStorage.token, isNull);
  });

  testWidgets('registro de visitante: pide el nombre, manda rol turista y entra al inicio', (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final user = _user(id: '2', email: 'nueva@correo.com', name: 'Nueva');
    await _pumpLoginForm(tester, AuthService(client: _authClient(user, bodies: bodies)));

    await _tapText(tester, 'Regístrate gratis');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('name-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('category-field')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Nueva');
    await tester.enterText(find.byKey(const ValueKey('email-field')), 'nueva@correo.com');
    await tester.enterText(find.byKey(const ValueKey('password-field')), _contrasenaSegura);
    await _tapText(tester, 'Crear cuenta');
    await _pumpNavigation(tester);

    expect(bodies.single, containsPair('rol', 'turista'));
    expect(bodies.single, containsPair('name', 'Nueva'));
    expect(find.byType(HomePage), findsOneWidget);
    await _disposeTree(tester);
  });

  testWidgets('registro de empresa: manda rol negocio + categoría y queda en revisión', (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final user = _user(role: 'negocio', name: 'Café del Puerto', negocios: [_negocio()]);
    await _pumpLoginForm(tester, AuthService(client: _authClient(user, bodies: bodies)));

    await _tapText(tester, 'Empresa');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Registra tu negocio');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Café del Puerto');
    // El tipo se elige de una lista: no es texto libre.
    expect(find.byKey(const ValueKey('category-other-field')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('category-field')));
    await tester.pumpAndSettle();
    expect(find.text('Club de playa'), findsWidgets);
    expect(find.text('Club nocturno'), findsWidgets);
    await tester.tap(find.text('Restaurante').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('email-field')), 'cafe@correo.com');
    await tester.enterText(find.byKey(const ValueKey('password-field')), _contrasenaSegura);
    await _tapText(tester, 'Solicitar registro');
    await tester.pumpAndSettle();

    expect(bodies.single, containsPair('rol', 'negocio'));
    expect(bodies.single, containsPair('categoria', 'Restaurante'));
    expect(find.text('Tu negocio está en revisión'), findsOneWidget);
  });

  testWidgets('registro de empresa: el tipo es obligatorio y con "Otro" se escribe de qué es', (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final user = _user(role: 'negocio', name: 'Kayaks Manzanillo', negocios: [_negocio()]);
    await _pumpLoginForm(tester, AuthService(client: _authClient(user, bodies: bodies)));

    await _tapText(tester, 'Empresa');
    await tester.pumpAndSettle();
    await _tapText(tester, 'Registra tu negocio');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Kayaks Manzanillo');
    await tester.enterText(find.byKey(const ValueKey('email-field')), 'kayaks@correo.com');
    await tester.enterText(find.byKey(const ValueKey('password-field')), _contrasenaSegura);

    // Sin elegir tipo no se manda.
    await _tapText(tester, 'Solicitar registro');
    await tester.pumpAndSettle();
    expect(find.text('Selecciona el tipo de negocio'), findsOneWidget);
    expect(bodies, isEmpty);

    // "Otro" pide escribir de qué es, y eso es lo que se guarda.
    await tester.tap(find.byKey(const ValueKey('category-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otro').last);
    await tester.pumpAndSettle();
    await _tapText(tester, 'Solicitar registro');
    await tester.pumpAndSettle();
    expect(find.text('Escribe de qué es tu negocio'), findsOneWidget);
    expect(bodies, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('category-other-field')), 'Renta de kayaks');
    await _tapText(tester, 'Solicitar registro');
    await tester.pumpAndSettle();

    expect(bodies.single, containsPair('categoria', 'Renta de kayaks'));
  });

  testWidgets('registro: una contraseña débil no se manda y dice qué le falta', (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final user = _user(id: '3', email: 'debil@correo.com', name: 'Débil');
    await _pumpLoginForm(tester, AuthService(client: _authClient(user, bodies: bodies)));

    await _tapText(tester, 'Regístrate gratis');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Débil');
    await tester.enterText(find.byKey(const ValueKey('email-field')), 'debil@correo.com');
    await tester.enterText(find.byKey(const ValueKey('password-field')), _contrasenaExistente);
    await _tapText(tester, 'Crear cuenta');
    await tester.pumpAndSettle();

    expect(find.text('Agrega un carácter especial (!@#\$...)'), findsOneWidget);
    expect(bodies, isEmpty, reason: 'no se llama al backend con una contraseña que no cumple');
    await _disposeTree(tester);
  });

  testWidgets('login: una cuenta existente entra aunque su contraseña no cumpla las reglas nuevas', (tester) async {
    final bodies = <Map<String, dynamic>>[];
    await _pumpLoginForm(tester, AuthService(client: _authClient(_user(), bodies: bodies)));

    await _submitLogin(tester, password: _contrasenaExistente);
    await _pumpNavigation(tester);

    expect(bodies.single, containsPair('password', _contrasenaExistente));
    expect(find.byType(HomePage), findsOneWidget);
    await _disposeTree(tester);
  });
}
