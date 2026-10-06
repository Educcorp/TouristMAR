import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:touristmar_web/navegacion/rutas.dart';
import 'package:touristmar_web/navegacion/sesion.dart';
import 'package:touristmar_web/pages/admin/admin_dashboard_page.dart';
import 'package:touristmar_web/services/auth_service.dart';
import 'package:touristmar_web/services/session_storage.dart';
import 'package:touristmar_web/widgets/admin/admin_shell.dart';
import 'package:touristmar_web/widgets/login_form.dart';

const _turista = AuthUser(id: '1', email: 'ana@correo.com', name: 'Ana', role: 'turista');
const _admin = AuthUser(id: '2', email: 'admin@touristmar.mx', name: 'Admin', role: 'admin');

Future<GoRouter> _montar(WidgetTester tester, String ruta) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = crearRouter(inicial: ruta);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  return router;
}

String _ruta(GoRouter router) => router.routerDelegate.currentConfiguration.uri.toString();

/// Desmonta la app para cancelar los temporizadores (sesión y campana).
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    SessionStorage.clearToken();
    reiniciarSesionParaPruebas();
  });

  testWidgets('sin sesión, cualquier ruta lleva al login', (tester) async {
    final router = await _montar(tester, '/admin/mapa');

    expect(_ruta(router), '/login');
    expect(find.byType(LoginForm), findsOneWidget);
  });

  testWidgets('con sesión, /login regresa al inicio del rol: "atrás" ya no saca hasta el login', (tester) async {
    Sesion.iniciar(_turista);
    final router = await _montar(tester, '/inicio');

    router.go('/login');
    await tester.pump();

    expect(_ruta(router), '/inicio');
    expect(find.byType(LoginForm), findsNothing);
    await _desmontar(tester);
  });

  testWidgets('un visitante no puede entrar al panel admin', (tester) async {
    Sesion.iniciar(_turista);
    final router = await _montar(tester, '/admin/usuarios');

    expect(_ruta(router), '/inicio');
    await _desmontar(tester);
  });

  testWidgets('cada sección del admin tiene su URL y se puede abrir directo', (tester) async {
    Sesion.iniciar(_admin);
    final router = await _montar(tester, '/admin/usuarios');

    expect(tester.widget<AdminDashboardPage>(find.byType(AdminDashboardPage)).seccion, AdminSection.usuarios);

    // El menú lateral cambia la URL.
    await tester.tap(find.text('Mapa y RA'));
    await tester.pump();
    expect(_ruta(router), '/admin/mapa');
    expect(tester.widget<AdminDashboardPage>(find.byType(AdminDashboardPage)).seccion, AdminSection.mapa);

    // "Recorridos 360°" ya no es una sección aparte.
    expect(find.text('Recorridos 360°'), findsNothing);
    await _desmontar(tester);
  });

  testWidgets('cerrar sesión lleva al login y el panel ya no se puede abrir', (tester) async {
    Sesion.iniciar(_admin);
    final router = await _montar(tester, '/admin/inicio');

    Sesion.cerrar();
    await tester.pump();
    expect(_ruta(router), '/login');

    router.go('/admin/inicio');
    await tester.pump();
    expect(_ruta(router), '/login');
  });
}
