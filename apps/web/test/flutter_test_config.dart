import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touristmar_web/services/auth_service.dart' show crearClienteHttp;
import 'package:touristmar_web/widgets/mapa/mapa_lugares.dart';

/// Configuración que Flutter aplica a TODAS las pruebas de esta carpeta
/// (también a las que se agreguen después), antes de su `main()`. Hace que
/// den lo mismo en la VM (`flutter test`) y en Chrome (`npm test`).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Mapas sin mosaicos de OpenStreetMap: en Chrome se descargan de verdad y
  // su animación de entrada no deja terminar a `pumpAndSettle`. Pines,
  // círculos y rutas se siguen dibujando.
  MapaBase.mostrarMosaicos = false;

  // Ninguna prueba sale a internet: un servicio creado sin `client:` responde
  // al instante con un error. En la VM ya fallaban rápido, pero en Chrome se
  // quedaban esperando y el "cargando…" giraba para siempre (pumpAndSettle
  // timed out). Los servicios que reciben su propio MockClient no cambian.
  crearClienteHttp = () => MockClient((_) async => http.Response('{"error":"Sin servidor en las pruebas"}', 503));

  await testMain();
}
