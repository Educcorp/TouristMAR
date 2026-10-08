// Pruebas del aviso obligatorio "Completa la información de tu negocio" y del
// selector de horario (días y horas en vez de texto libre).
//
// No necesitan backend: se corren con
//
//   cd apps/web
//   flutter test test/negocio_informacion_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touristmar_web/models/business_profile.dart';
import 'package:touristmar_web/models/horario.dart';
import 'package:touristmar_web/navegacion/rutas.dart';
import 'package:touristmar_web/navegacion/sesion.dart';
import 'package:touristmar_web/pages/business_edit_page.dart';
import 'package:touristmar_web/services/auth_service.dart';
import 'package:touristmar_web/services/session_storage.dart';
import 'package:touristmar_web/widgets/business/aviso_informacion_incompleta.dart';
import 'package:touristmar_web/widgets/horario_field.dart';

// ── Datos de prueba ─────────────────────────────────────────────────────────

const _horarioValido = 'Lun–Vie 9:00 AM – 6:00 PM · Sáb–Dom Cerrado';

NegocioInfo _negocioInfo({
  String? portada,
  double? latitud,
  double? longitud,
  String? horario,
  String? telefono = '314 123 4567',
}) =>
    NegocioInfo(
      id: 'n-1',
      nombre: 'Café del Puerto',
      categoria: 'Restaurante',
      descripcion: 'Mariscos frente al mar',
      direccion: 'Av. Principal 1',
      telefono: telefono,
      horario: horario,
      portada: portada,
      latitud: latitud,
      longitud: longitud,
      estado: 'aprobado',
      createdAt: DateTime(2026, 9, 1),
    );

AuthUser _empresa(NegocioInfo negocio) =>
    AuthUser(id: 'u-1', email: 'cafe@correo.com', name: 'Ana', role: 'negocio', negocios: [negocio]);

BusinessProfile _perfil(NegocioInfo negocio) => BusinessProfile.fromNegocioInfo(_empresa(negocio), negocio);

/// Negocio aprobado al que le falta casi todo lo de la ficha.
final _incompleto = _negocioInfo(horario: 'Lun a Dom 9:00 a 18:00');

/// Negocio con la ficha completa.
final _completo = _negocioInfo(
  portada: 'https://cdn.test/portada.png',
  latitud: 19.05,
  longitud: -104.31,
  horario: _horarioValido,
);

// ── Ayudas ──────────────────────────────────────────────────────────────────

void _pantallaCelular(WidgetTester tester, {double ancho = 430, double alto = 2400}) {
  tester.view.physicalSize = Size(ancho, alto);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// En las pruebas las imágenes de red no existen y, con la fuente de pruebas
/// (Ahem), la franja de créditos de OpenStreetMap no cabe. Solo se ignoran
/// esos dos avisos.
void _ignorarImagenesYCreditosDelMapa() {
  final onError = FlutterError.onError;
  FlutterError.onError = (d) {
    final imagen = d.library == 'image resource service';
    final creditos = d.toString().contains('flutter_map') && d.toString().contains('overflowed');
    if (!imagen && !creditos) onError?.call(d);
  };
  addTearDown(() => FlutterError.onError = onError);
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

void main() {
  setUp(SessionStorage.clearToken);

  group('Horario (formato fijo)', () {
    test('agrupa los días seguidos con el mismo horario', () {
      expect(HorarioSemanal.predeterminado().formatear(), _horarioValido);
    });

    test('se puede leer de vuelta lo que se guardó', () {
      final h = HorarioSemanal.predeterminado()
          .conDia(0, HorarioDia.abierto(HoraDelDia.desde12(10, 30, false), HoraDelDia.desde12(11, 0, true)))
          .conDia(5, HorarioDia.abierto(HoraDelDia.desde12(8, 0, true), HoraDelDia.desde12(2, 0, false)));
      final texto = h.formatear();
      expect(texto, 'Lun 10:30 AM – 11:00 PM · Mar–Vie 9:00 AM – 6:00 PM · Sáb 8:00 PM – 2:00 AM · Dom Cerrado');
      expect(HorarioSemanal.parse(texto)?.formatear(), texto);
    });

    test('las 12 del día y de la noche', () {
      expect(HoraDelDia.formatear(0), '12:00 AM');
      expect(HoraDelDia.formatear(12 * 60), '12:00 PM');
      expect(HoraDelDia.desde12(12, 0, false), 0);
      expect(HoraDelDia.desde12(12, 0, true), 12 * 60);
    });

    test('un horario escrito a mano o incompleto no se acepta', () {
      expect(HorarioSemanal.parse('Lun a Dom 9:00 a 18:00'), isNull);
      expect(HorarioSemanal.parse('Lun–Vie 9:00 AM – 6:00 PM'), isNull, reason: 'faltan sábado y domingo');
      expect(HorarioSemanal.parse('Lun–Dom 13:00 AM – 6:00 PM'), isNull);
      expect(HorarioSemanal.parse(''), isNull);
      expect(HorarioSemanal.parse(null), isNull);
    });
  });

  group('Ficha completa del negocio', () {
    test('dice qué le falta', () {
      expect(_perfil(_incompleto).datosFaltantes, [
        'Foto de portada',
        'Ubicación en el mapa',
        'Horario (días y horas)',
      ]);
      expect(_perfil(_negocioInfo(telefono: '12')).datosFaltantes, contains('Teléfono'));
    });

    test('con todo lleno está completa', () {
      expect(_perfil(_completo).informacionCompleta, isTrue);
    });

    test('el aviso lleva a "Editar negocio" en modo obligatorio', () {
      expect(rutaCompletarNegocio('n-1'), '/empresa/editar?negocio=n-1&completar=1');
    });
  });

  testWidgets('Selector de horario: días con interruptor y horas con listas (sin escribir)', (tester) async {
    _pantallaCelular(tester);
    String? horario;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HorarioField(inicial: null, acento: Colors.orange, onChanged: (v) => horario = v),
          ),
        ),
      ),
    );

    expect(find.text('Sin configurar. Toca para elegir días y horas.'), findsOneWidget);
    await _tocar(tester, find.byKey(const ValueKey('horario-desplegar')));
    expect(find.text('Lunes'), findsOneWidget);
    expect(find.text('Domingo'), findsOneWidget);
    expect(horario, _horarioValido, reason: 'al abrirlo propone lunes a viernes de 9 a 6');

    // Abre también el sábado…
    await _tocar(tester, find.byKey(const ValueKey('horario-5-abierto')));
    // …y el lunes abre a las 10.
    await _tocar(tester, find.byKey(const ValueKey('horario-0-abre-hora')));
    await tester.tap(find.text('10').last);
    await tester.pumpAndSettle();

    expect(horario, 'Lun 10:00 AM – 6:00 PM · Mar–Sáb 9:00 AM – 6:00 PM · Dom Cerrado');
  });

  testWidgets('El aviso no se puede cerrar: tocar fuera explica que primero hay que completar', (tester) async {
    _pantallaCelular(tester);
    bool? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => resultado = await mostrarAvisoInformacionIncompleta(context, _perfil(_incompleto)),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await _tocar(tester, find.text('Abrir'));

    expect(find.text('Completa la información de tu negocio'), findsOneWidget);
    expect(find.text('Foto de portada'), findsOneWidget);
    expect(find.text('Horario (días y horas)'), findsOneWidget);

    // Tocar fuera del aviso no lo cierra.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Completa la información de tu negocio'), findsOneWidget);
    expect(find.text(mensajeCompletarPrimero), findsOneWidget);

    await _tocar(tester, find.text('Completar mi información'));
    expect(resultado, isTrue);
    expect(find.text('Completa la información de tu negocio'), findsNothing);
  });

  testWidgets('"Editar negocio" en modo obligatorio no deja salir y pide portada y ubicación', (tester) async {
    _pantallaCelular(tester);
    _ignorarImagenesYCreditosDelMapa();
    await tester.pumpWidget(
      MaterialApp(home: BusinessEditPage(business: _perfil(_incompleto), obligatorio: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completa la información de tu negocio'), findsOneWidget);
    expect(find.textContaining('Para continuar completa:'), findsOneWidget);
    // El horario escrito a mano no sirve: el selector ya viene abierto.
    expect(find.text('Lunes'), findsOneWidget);

    // "Cancelar" no sale, avisa.
    await _tocar(tester, find.text('Cancelar'));
    expect(find.byType(BusinessEditPage), findsOneWidget);
    expect(find.text(mensajeCompletarPrimero), findsOneWidget);

    // Se espera a que se quite el aviso de abajo para que no tape el botón.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Guardar sin portada ni pin no se permite.
    await _tocar(tester, find.text('Guardar cambios'));
    expect(find.text('Para continuar falta la foto de portada y la ubicación en el mapa.'), findsOneWidget);
    expect(find.byType(BusinessEditPage), findsOneWidget);
  });

  group('Panel de empresa', () {
    Future<void> abrirPanel(WidgetTester tester, NegocioInfo negocio) async {
      // Pantalla de escritorio, como el resto de las pruebas del panel.
      _pantallaCelular(tester, ancho: 1200);
      _ignorarImagenesYCreditosDelMapa();
      Sesion.iniciar(_empresa(negocio));
      addTearDown(reiniciarSesionParaPruebas);
      final router = crearRouter(inicial: '/empresa/inicio');
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
    }

    testWidgets('con la ficha incompleta sale el aviso y lleva a completarla', (tester) async {
      await abrirPanel(tester, _incompleto);

      expect(find.text('Completa la información de tu negocio'), findsOneWidget);
      await _tocar(tester, find.text('Completar mi información'));

      expect(find.byType(BusinessEditPage), findsOneWidget);
      expect(tester.widget<BusinessEditPage>(find.byType(BusinessEditPage)).obligatorio, isTrue);
      // Mientras llena la ficha el aviso no vuelve a salir encima del
      // formulario (el router reconstruye el panel que queda debajo).
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(AvisoInformacionIncompleta), findsNothing);
      expect(find.text('Completar mi información'), findsNothing);
      await tester.enterText(find.byType(EditableText).first, 'Café del Puerto Centro');
      await tester.pumpAndSettle();
      expect(find.byType(AvisoInformacionIncompleta), findsNothing);
      await _desmontar(tester);
    });

    testWidgets('con la ficha completa no sale ningún aviso', (tester) async {
      await abrirPanel(tester, _completo);
      expect(find.text('Completa la información de tu negocio'), findsNothing);
      await _desmontar(tester);
    });
  });
}
