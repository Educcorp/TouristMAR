import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/models/lugar.dart';
import 'package:touristmar_web/services/resenas_service.dart';
import 'package:touristmar_web/widgets/resenas/resenas_lugar_section.dart';

const _negocioId = '44444444-4444-4444-8444-444444444444';

Map<String, dynamic> _resena({
  String id = 'r1',
  int estrellas = 5,
  String? comentario = 'Excelente lugar',
  String? respuesta,
  String autor = 'Carlos M.',
  bool mia = false,
}) =>
    {
      'id': id,
      'estrellas': estrellas,
      'comentario': comentario,
      'respuesta': respuesta,
      'respuestaEn': null,
      'createdAt': '2026-09-08T12:00:00.000Z',
      'autor': {'nombre': autor, 'avatarUrl': null},
      'mia': mia,
    };

Map<String, dynamic> _respuestaLugar(List<Map<String, dynamic>> resenas) => {
      'resumen': {
        'promedio': resenas.isEmpty ? 0 : 4.5,
        'total': resenas.length,
        'porEstrellas': [0, 0, 0, resenas.isEmpty ? 0 : 1, resenas.isEmpty ? 0 : 1],
      },
      'resenas': resenas,
    };

const _lugarReal = Lugar(id: _negocioId, nombre: 'Playa Las Brisas', categoriaTexto: 'Playa', portada: 'x.jpg');
const _lugarDemo = Lugar(id: 'demo-audiencia', nombre: 'Playa La Audiencia', categoriaTexto: 'Playa', portada: 'x.jpg');

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('modelos', () {
    test('fechaCorta usa el mismo formato que el resto de la app', () {
      expect(fechaCorta(DateTime(2026, 9, 8)), '8 sep 2026');
      expect(fechaCorta(DateTime(2026, 1, 15)), '15 ene 2026');
    });

    test('ResumenResenas calcula el porcentaje por estrellas', () {
      const r = ResumenResenas(promedio: 4.5, total: 4, porEstrellas: [0, 0, 0, 2, 2]);
      expect(r.porcentaje(5), 50);
      expect(r.porcentaje(4), 50);
      expect(r.porcentaje(1), 0);
      expect(const ResumenResenas().porcentaje(5), 0);
    });

    test('Resena.fromJson lee el autor y si es la propia', () {
      final r = Resena.fromJson(_resena(mia: true));
      expect(r.autorNombre, 'Carlos M.');
      expect(r.mia, isTrue);
      expect(r.estrellas, 5);
    });

    test('Lugar.fromJson trae la calificación real del backend', () {
      final lugar = Lugar.fromJson({
        'id': _negocioId,
        'nombre': 'Playa Las Brisas',
        'estado': 'aprobado',
        'galeria': <String>[],
        'createdAt': '2026-09-01T00:00:00.000Z',
        'rating': 4.5,
        'totalResenas': 2,
      });
      expect(lugar.rating, 4.5);
      expect(lugar.totalResenas, 2);
    });
  });

  group('ResenasService', () {
    test('guardar manda estrellas y comentario por PUT', () async {
      late http.Request enviado;
      final service = ResenasService(client: MockClient((request) async {
        enviado = request;
        return http.Response('', 204);
      }));

      await service.guardar(_negocioId, estrellas: 4, comentario: 'Bonito');

      expect(enviado.method, 'PUT');
      expect(enviado.url.path, endsWith('/resenas/lugar/$_negocioId'));
      expect(jsonDecode(enviado.body), {'estrellas': 4, 'comentario': 'Bonito'});
    });

    test('un error del servidor se convierte en ResenasError con su mensaje', () async {
      final service = ResenasService(
        client: MockClient((_) async => http.Response(jsonEncode({'error': 'No puedes reseñar tu propio negocio'}), 403)),
      );

      expect(
        () => service.guardar(_negocioId, estrellas: 5),
        throwsA(isA<ResenasError>().having((e) => e.message, 'message', 'No puedes reseñar tu propio negocio')),
      );
    });
  });

  group('ResenasLugarSection', () {
    testWidgets('un lugar de ejemplo avisa que no tiene reseñas reales y no llama al servidor', (tester) async {
      var llamadas = 0;
      final service = ResenasService(client: MockClient((_) async {
        llamadas++;
        return http.Response('{}', 200);
      }));

      await tester.pumpWidget(_app(ResenasLugarSection(lugar: _lugarDemo, service: service)));
      await tester.pumpAndSettle();

      expect(find.textContaining('de ejemplo'), findsOneWidget);
      expect(find.text('Publicar reseña'), findsNothing);
      expect(llamadas, 0);
    });

    testWidgets('muestra las reseñas con la respuesta del negocio y el formulario para opinar', (tester) async {
      final service = ResenasService(
        client: MockClient((_) async => http.Response(
              jsonEncode(_respuestaLugar([_resena(respuesta: 'Gracias por visitarnos')])),
              200,
            )),
      );
      ResumenResenas? resumen;

      await tester.pumpWidget(_app(ResenasLugarSection(lugar: _lugarReal, service: service, onResumen: (r) => resumen = r)));
      await tester.pumpAndSettle();

      expect(find.text('Excelente lugar'), findsOneWidget);
      expect(find.text('Carlos M.'), findsOneWidget);
      expect(find.text('Gracias por visitarnos'), findsOneWidget);
      expect(find.text('Deja tu reseña'), findsOneWidget);
      expect(resumen?.total, 1);
    });

    testWidgets('sin reseñas invita a escribir la primera', (tester) async {
      final service = ResenasService(client: MockClient((_) async => http.Response(jsonEncode(_respuestaLugar([])), 200)));

      await tester.pumpWidget(_app(ResenasLugarSection(lugar: _lugarReal, service: service)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sé el primero'), findsOneWidget);
    });

    testWidgets('en vista previa (negocio o admin) no hay formulario', (tester) async {
      final service = ResenasService(client: MockClient((_) async => http.Response(jsonEncode(_respuestaLugar([_resena()])), 200)));

      await tester.pumpWidget(_app(ResenasLugarSection(lugar: _lugarReal, vistaPrevia: true, service: service)));
      await tester.pumpAndSettle();

      expect(find.text('Deja tu reseña'), findsNothing);
      expect(find.text('Excelente lugar'), findsOneWidget);
    });

    testWidgets('exige elegir estrellas antes de publicar', (tester) async {
      var guardados = 0;
      final service = ResenasService(client: MockClient((request) async {
        if (request.method == 'PUT') guardados++;
        return http.Response(jsonEncode(_respuestaLugar([])), 200);
      }));

      await tester.pumpWidget(_app(ResenasLugarSection(lugar: _lugarReal, service: service)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publicar reseña'));
      await tester.pump();

      expect(find.text('Elige de 1 a 5 estrellas'), findsOneWidget);
      expect(guardados, 0);
    });

    testWidgets('publica la reseña con las estrellas y el comentario elegidos', (tester) async {
      Map<String, dynamic>? cuerpo;
      final service = ResenasService(client: MockClient((request) async {
        if (request.method == 'PUT') {
          cuerpo = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('', 204);
        }
        return http.Response(jsonEncode(_respuestaLugar([])), 200);
      }));

      await tester.pumpWidget(_app(ResenasLugarSection(lugar: _lugarReal, service: service)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('4 estrellas'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Muy bonito');
      await tester.tap(find.text('Publicar reseña'));
      await tester.pumpAndSettle();

      expect(cuerpo, {'estrellas': 4, 'comentario': 'Muy bonito'});
    });
  });
}
