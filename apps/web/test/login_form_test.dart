import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/services/auth_service.dart';
import 'package:touristmar_web/widgets/login_form.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Map<String, dynamic> _user({String id = '1', String email = 'ana@correo.com', String name = 'Ana'}) => {
      'id': id,
      'email': email,
      'name': name,
      'role': 'usuario',
      'avatarUrl': null,
    };

void main() {
  testWidgets('inicia sesión con email/password y muestra el saludo de bienvenida', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(jsonEncode({'token': 'jwt-token', 'user': _user()}), 200);
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(_wrap(LoginForm(authService: AuthService(client: client))));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('email-field')), 'ana@correo.com');
    await tester.enterText(find.byKey(const ValueKey('password-field')), 'password123');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bienvenido, Ana'), findsOneWidget);
  });

  testWidgets('muestra un error inline cuando el login falla', (tester) async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'error': 'Correo o contraseña incorrectos'}), 401);
    });

    await tester.pumpWidget(_wrap(LoginForm(authService: AuthService(client: client))));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('email-field')), 'ana@correo.com');
    await tester.enterText(find.byKey(const ValueKey('password-field')), 'incorrecta');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
  });

  testWidgets('cambia a modo registro, pide el campo nombre y llama a register', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/register')) {
        return http.Response(jsonEncode({'token': 'jwt-token-2', 'user': _user(id: '2', email: 'nueva@correo.com', name: 'Nueva')}), 200);
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(_wrap(LoginForm(authService: AuthService(client: client))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Regístrate gratis'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('name-field')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('name-field')), 'Nueva');
    await tester.enterText(find.byKey(const ValueKey('email-field')), 'nueva@correo.com');
    await tester.enterText(find.byKey(const ValueKey('password-field')), 'password123');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bienvenido, Nueva'), findsOneWidget);
  });

  testWidgets('cierra sesión y vuelve al formulario', (tester) async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'token': 'jwt-token', 'user': _user()}), 200);
    });

    await tester.pumpWidget(_wrap(LoginForm(authService: AuthService(client: client))));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('email-field')), 'ana@correo.com');
    await tester.enterText(find.byKey(const ValueKey('password-field')), 'password123');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('email-field')), findsOneWidget);
  });
}
