import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/services/auth_service.dart';
import 'package:touristmar_web/services/recorridos_service.dart';

Map<String, dynamic> _escenaJson(String id, int posicion) => {
      'id': id,
      'posicion': posicion,
      'imagenUrl': 'https://cdn/r-1/$id.jpg',
      'miniaturaUrl': 'https://cdn/r-1/${id}_min.jpg',
      'ancho': 4096,
      'alto': 2048,
      'pesoBytes': 1048576,
      'createdAt': '2026-09-01T00:00:00.000Z',
    };

Map<String, dynamic> _recorridoJson({Map<String, dynamic> overrides = const {}}) => {
      'id': 'r-1',
      'nombre': 'cerro_vigia_360',
      'titulo': 'Cerro del Vigía',
      'texto': 'Mirador con vista a la bahía.',
      'negocioId': null,
      'negocioNombre': null,
      'activo': true,
      'escenas': [_escenaJson('e-1', 1), _escenaJson('e-2', 2), _escenaJson('e-3', 3)],
      'createdAt': '2026-09-01T00:00:00.000Z',
      'updatedAt': '2026-09-02T00:00:00.000Z',
      ...overrides,
    };

void main() {
  test('listRecorridos pide /admin/recorridos con el token y arma las escenas', () async {
    http.Request? called;
    final client = MockClient((request) async {
      called = request;
      return http.Response(jsonEncode({'recorridos': [_recorridoJson()]}), 200);
    });

    final list = await RecorridosService(client: client).listRecorridos('jwt');

    expect(called!.url.path, endsWith('/admin/recorridos'));
    expect(called!.headers['Authorization'], 'Bearer jwt');
    final r = list.single;
    expect(r.escenas.map((e) => e.posicion), [1, 2, 3]);
    expect(r.foto(2)!.id, 'e-2');
    expect(r.pesoTotalBytes, 3 * 1048576);
    expect(r.publicado, isTrue);
  });

  test('un recorrido al que le falta una foto no cuenta como publicado', () {
    final r = Recorrido360.fromJson(_recorridoJson(overrides: {
      'escenas': [_escenaJson('e-1', 1), _escenaJson('e-3', 3)],
    }));
    expect(r.publicado, isFalse);
    expect(r.foto(2), isNull);
  });

  test('createRecorrido manda JSON con negocioId null si es general', () async {
    late Map<String, dynamic> body;
    final client = MockClient((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'recorrido': _recorridoJson(overrides: {'escenas': []})}), 201);
    });

    final r = await RecorridosService(client: client).createRecorrido(
      'jwt',
      nombre: 'cerro_vigia_360',
      titulo: 'Cerro del Vigía',
      texto: 'Mirador.',
    );

    expect(body, {'nombre': 'cerro_vigia_360', 'titulo': 'Cerro del Vigía', 'texto': 'Mirador.', 'negocioId': null});
    expect(r.escenas, isEmpty);
  });

  test('setEscena sube la foto a su casilla (PUT .../escenas/2) como stream multipart', () async {
    late String body;
    late http.BaseRequest called;
    final client = MockClient.streaming((request, stream) async {
      called = request;
      body = latin1.decode(await stream.toBytes());
      return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode({'escena': _escenaJson('e-2', 2)}))), 200);
    });

    final escena = await RecorridosService(client: client).setEscena(
      'jwt',
      'r-1',
      2,
      bytes: Stream.value([1, 2, 3]),
      length: 3,
      filename: 'foto1.JPG',
    );

    expect(called.method, 'PUT');
    expect(called.url.path, endsWith('/admin/recorridos/r-1/escenas/2'));
    expect(body, contains('content-type: image/jpeg'));
    // La casilla manda, no el nombre del archivo.
    expect(escena.posicion, 2);
  });

  test('deleteEscena quita la foto de su casilla', () async {
    late http.Request called;
    final client = MockClient((request) async {
      called = request;
      return http.Response('', 204);
    });

    await RecorridosService(client: client).deleteEscena('jwt', 'r-1', 3);

    expect(called.method, 'DELETE');
    expect(called.url.path, endsWith('/admin/recorridos/r-1/escenas/3'));
  });

  test('listPublicos filtra por negocio sin token', () async {
    late http.Request called;
    final client = MockClient((request) async {
      called = request;
      return http.Response(
        jsonEncode({
          'recorridos': [
            {
              'nombre': 'hotel_360',
              'textoParaMostrar': 'Hotel\nInfo',
              'negocioId': 'n-1',
              'urlPortada': 'https://cdn/min.jpg',
              'escenas': [
                {'titulo': 'Foto 1', 'urlImagen': 'https://cdn/1.jpg'},
                {'titulo': 'Foto 2', 'urlImagen': 'https://cdn/2.jpg'},
                {'titulo': 'Foto 3', 'urlImagen': 'https://cdn/3.jpg'},
              ],
            },
          ],
        }),
        200,
      );
    });

    final list = await RecorridosService(client: client).listPublicos(negocioId: 'n-1');

    expect(called.url.path, endsWith('/recorridos'));
    expect(called.url.queryParameters, {'negocioId': 'n-1'});
    expect(called.headers.containsKey('Authorization'), isFalse);
    expect(list.single.escenas, 3);
  });

  group('recorridoDeLugar', () {
    RecorridoPublico r(String nombre, {String negocioId = '', String titulo = 'Otro lugar'}) => RecorridoPublico(
          nombre: nombre,
          textoParaMostrar: '$titulo\nInfo',
          negocioId: negocioId,
          urlPortada: '',
          escenas: 3,
        );

    final publicados = [
      r('cerro_vigia_360', titulo: 'Cerro del Vigía'),
      r('hotel_360', negocioId: 'n-1', titulo: 'Hotel'),
      r('playa_la_audiencia_360', titulo: 'Bahía de Santiago'),
    ];

    test('un lugar sin recorrido propio no recibe el de otro lugar', () {
      expect(recorridoDeLugar(publicados, lugarId: 'demo-miramar', lugarNombre: 'Playa Miramar'), isNull);
      expect(recorridoDeLugar(publicados, lugarId: 'n-2', lugarNombre: 'Restaurante'), isNull);
      expect(recorridoDeLugar(const [], lugarId: 'n-1', lugarNombre: 'Hotel'), isNull);
    });

    test('encuentra el suyo por negocio, por nombre o por título', () {
      expect(recorridoDeLugar(publicados, lugarId: 'n-1', lugarNombre: 'Cualquiera')!.nombre, 'hotel_360');
      expect(recorridoDeLugar(publicados, lugarId: 'demo-audiencia', lugarNombre: 'Playa La Audiencia')!.nombre,
          'playa_la_audiencia_360');
      expect(recorridoDeLugar(publicados, lugarId: 'demo-vigia', lugarNombre: 'Cerro del Vigia')!.nombre,
          'cerro_vigia_360');
    });

    test('no confunde lugares con nombres parecidos', () {
      expect(recorridoDeLugar(publicados, lugarId: 'x', lugarNombre: 'Audiencia Norte'), isNull);
      expect(recorridoDeLugar(publicados, lugarId: 'x', lugarNombre: 'Cerro'), isNull);
    });
  });

  test('lanza AuthError con el mensaje del servidor', () async {
    final client = MockClient((_) async => http.Response(jsonEncode({'error': 'La foto mide 2048×2048'}), 400));

    expect(
      () => RecorridosService(client: client).deleteEscena('jwt', 'r-1', 1),
      throwsA(isA<AuthError>().having((e) => e.message, 'message', 'La foto mide 2048×2048')),
    );
  });
}
