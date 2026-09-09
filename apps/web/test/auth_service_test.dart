import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/services/auth_service.dart';

void main() {
  group('login', () {
    test('hace POST a /auth/login y devuelve token + usuario', () async {
      final authResponse = {
        'token': 'jwt-token',
        'user': {'id': '1', 'email': 'ana@correo.com', 'name': 'Ana', 'role': 'usuario', 'avatarUrl': null},
      };

      Uri? calledUri;
      String? calledBody;

      final client = MockClient((request) async {
        calledUri = request.url;
        calledBody = request.body;
        return http.Response(jsonEncode(authResponse), 200);
      });

      final result = await AuthService(client: client).login('ana@correo.com', 'password123');

      expect(calledUri.toString(), contains('/auth/login'));
      expect(calledBody, jsonEncode({'email': 'ana@correo.com', 'password': 'password123'}));
      expect(result.token, 'jwt-token');
      expect(result.user.email, 'ana@correo.com');
    });

    test('lanza AuthError con el mensaje del servidor cuando la respuesta no es ok', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Correo o contraseña incorrectos'}), 401);
      });

      expect(
        () => AuthService(client: client).login('ana@correo.com', 'mala'),
        throwsA(isA<AuthError>().having((e) => e.message, 'message', 'Correo o contraseña incorrectos')),
      );
    });

    test('usa un mensaje genérico si el servidor no manda JSON válido', () async {
      final client = MockClient((request) async => http.Response('no es json', 400));

      expect(
        () => AuthService(client: client).login('ana@correo.com', 'mala'),
        throwsA(isA<AuthError>().having((e) => e.message, 'message', 'No se pudo completar la solicitud')),
      );
    });
  });

  group('register', () {
    test('hace POST a /auth/register con email, password y name', () async {
      final authResponse = {
        'token': 'jwt-token',
        'user': {'id': '1', 'email': 'ana@correo.com', 'name': 'Ana', 'role': 'usuario', 'avatarUrl': null},
      };

      String? calledBody;
      final client = MockClient((request) async {
        calledBody = request.body;
        return http.Response(jsonEncode(authResponse), 200);
      });

      await AuthService(client: client).register('ana@correo.com', 'password123', 'Ana');

      expect(calledBody, jsonEncode({'email': 'ana@correo.com', 'password': 'password123', 'name': 'Ana'}));
    });
  });

  group('getCurrentUser', () {
    test('manda el bearer token y devuelve el usuario', () async {
      final user = {'id': '1', 'email': 'ana@correo.com', 'name': 'Ana', 'role': 'usuario', 'avatarUrl': null};

      Map<String, String>? calledHeaders;
      final client = MockClient((request) async {
        calledHeaders = request.headers;
        return http.Response(jsonEncode({'user': user}), 200);
      });

      final result = await AuthService(client: client).getCurrentUser('jwt-token');

      expect(calledHeaders?['Authorization'], 'Bearer jwt-token');
      expect(result.email, 'ana@correo.com');
    });

    test('lanza AuthError cuando el token es inválido', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'Token inválido o expirado'}), 401);
      });

      expect(
        () => AuthService(client: client).getCurrentUser('token-malo'),
        throwsA(isA<AuthError>()),
      );
    });
  });
}
