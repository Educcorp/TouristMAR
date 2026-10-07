import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

Stream<double> rumbo() {
  JSFunction? absoluta;
  JSFunction? relativa;
  late final StreamController<double> salida;
  salida = StreamController<double>(
    onListen: () {
      // Android (Chrome): alpha absoluto, antihorario desde el norte.
      absoluta = ((web.DeviceOrientationEvent e) {
        final alpha = e.alpha;
        if (alpha != null) salida.add((360 - alpha) % 360);
      }).toJS;
      // iPhone (Safari): ya viene el rumbo horario en webkitCompassHeading.
      relativa = ((web.DeviceOrientationEvent e) {
        final h = (e as JSObject).getProperty<JSNumber?>('webkitCompassHeading'.toJS);
        if (h != null) salida.add(h.toDartDouble % 360);
      }).toJS;
      web.window.addEventListener('deviceorientationabsolute', absoluta);
      web.window.addEventListener('deviceorientation', relativa);
    },
    onCancel: () {
      web.window.removeEventListener('deviceorientationabsolute', absoluta);
      web.window.removeEventListener('deviceorientation', relativa);
    },
  );
  return salida.stream;
}

Future<void> pedirPermiso() async {
  final evento = globalContext.getProperty<JSObject?>('DeviceOrientationEvent'.toJS);
  if (evento == null || !evento.has('requestPermission')) return;
  try {
    await evento.callMethod<JSPromise<JSAny?>>('requestPermission'.toJS).toDart;
  } catch (_) {
    // Lo negó o no hubo toque del usuario: la pantalla sigue sin brújula.
  }
}
