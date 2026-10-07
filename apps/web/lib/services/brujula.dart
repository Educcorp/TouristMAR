import 'brujula_nativa.dart' if (dart.library.js_interop) 'brujula_web.dart' as plataforma;

/// Brújula del dispositivo para la RA por ubicación: rumbo en grados respecto
/// al norte, en sentido horario (0 = norte, 90 = este). En el teléfono sale de
/// `flutter_compass`; en el navegador del evento `deviceorientationabsolute`
/// (o `webkitCompassHeading` en iPhone). Una computadora no tiene brújula: el
/// stream no emite nada y la pantalla lo indica.
class Brujula {
  Brujula._();

  static Stream<double> rumbo() => plataforma.rumbo();

  /// En iPhone (Safari) hay que pedir permiso desde un toque del usuario.
  static Future<void> pedirPermiso() => plataforma.pedirPermiso();
}
