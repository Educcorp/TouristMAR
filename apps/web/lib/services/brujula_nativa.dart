import 'package:flutter_compass/flutter_compass.dart';

Stream<double> rumbo() {
  final eventos = FlutterCompass.events;
  if (eventos == null) return const Stream.empty();
  return eventos.map((e) => e.heading).where((h) => h != null).map((h) => (h! + 360) % 360);
}

Future<void> pedirPermiso() async {}
