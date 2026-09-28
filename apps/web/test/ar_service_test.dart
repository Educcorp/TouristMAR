import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/services/ar_service.dart';
import 'package:touristmar_web/services/auth_service.dart';

Map<String, dynamic> _marcadorJson({Map<String, dynamic> overrides = const {}}) => {
      'id': 'm-1',
      'nombre': 'Gaviota',
      'imagenUrl': 'https://cdn/m-1/marcador?v=1',
      'anchoMetros': null,
      'titulo': 'Gaviota patiamarilla',
      'texto': 'Ave común en la bahía.',
      'tipoContenido': 'texto',
      'contenidoUrl': null,
      'negocioId': null,
      'negocioNombre': null,
      'activo': true,
      'escaneos': 3,
      'createdAt': '2026-09-01T00:00:00.000Z',
      'updatedAt': '2026-09-02T00:00:00.000Z',
      ...overrides,
    };

void main() {
  test('listMarcadores pide /admin/ar/marcadores con el token', () async {
    http.Request? called;
    final client = MockClient((request) async {
      called = request;
      return http.Response(jsonEncode({'marcadores': [_marcadorJson()]}), 200);
    });

    final list = await ArService(client: client).listMarcadores('jwt');

    expect(called!.url.path, endsWith('/admin/ar/marcadores'));
    expect(called!.headers['Authorization'], 'Bearer jwt');
    expect(list.single.titulo, 'Gaviota patiamarilla');
    expect(list.single.escaneos, 3);
    expect(list.single.anchoMetros, isNull);
  });

  test('createMarcador manda multipart con la imagen y los campos', () async {
    late String body;
    late String contentType;
    final client = MockClient.streaming((request, stream) async {
      contentType = request.headers['content-type']!;
      body = latin1.decode(await stream.toBytes());
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'marcador': _marcadorJson(overrides: {'anchoMetros': 0.3})}))),
        201,
      );
    });

    final m = await ArService(client: client).createMarcador(
      'jwt',
      imagen: Uint8List.fromList([1, 2, 3]),
      filename: 'gaviota.png',
      nombre: 'Gaviota',
      titulo: 'Gaviota patiamarilla',
      texto: 'Ave común en la bahía.',
      anchoMetros: 0.3,
    );

    expect(contentType, startsWith('multipart/form-data'));
    expect(body, contains('name="anchoMetros"\r\n\r\n0.3'));
    // Sin negocio va como campo vacío (el backend lo interpreta como null).
    expect(body, matches(RegExp(r'name="negocioId"\r\n(?:[^\r\n]+\r\n)*\r\n\r\n--')));
    expect(body, contains('content-type: image/png'));
    expect(m.anchoMetros, 0.3);
  });

  test('lanza AuthError con el mensaje del servidor', () async {
    final client = MockClient((_) async => http.Response(jsonEncode({'error': 'Formato no soportado'}), 400));

    expect(
      () => ArService(client: client).deleteMarcador('jwt', 'm-1'),
      throwsA(isA<AuthError>().having((e) => e.message, 'message', 'Formato no soportado')),
    );
  });
}
