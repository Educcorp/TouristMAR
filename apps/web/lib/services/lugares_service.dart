import '../models/lugar.dart';

/// Lo que todavía no existe en el backend. La interfaz lo atrapa y muestra
/// un aviso en lugar de fallar en silencio.
class PendienteBackend implements Exception {
  final String que;
  const PendienteBackend(this.que);

  @override
  String toString() => '$que todavía no está conectado con el servidor.';
}

/// Fuente de los puntos del mapa y de la configuración de experiencias.
///
/// Hoy responde con datos de ejemplo ([usaDatosDemo] = true) porque el
/// backend aún no expone:
///   - `GET  /api/lugares`                     → negocios aprobados con lat/lng
///   - `PUT  /api/auth/profile/negocios/:id/ubicacion`   { lat, lng }
///   - `PUT/DELETE /api/auth/profile/negocios/:id/experiencias/:tipo` (multipart)
///   - `PUT  /api/admin/experiencias/config`   { radioDesbloqueo, ... }
/// Cuando existan, solo cambia el cuerpo de estos métodos: las pantallas
/// ya consumen esta clase.
class LugaresService {
  const LugaresService();

  bool get usaDatosDemo => true;

  Future<List<Lugar>> listarPublicos() async => _lugaresDemo;

  Future<void> guardarUbicacion(String negocioId, Coordenadas ubicacion) async {
    throw const PendienteBackend('Guardar la ubicación del negocio');
  }

  Future<void> subirRecurso(String negocioId, ExperienciaTipo tipo) async {
    throw PendienteBackend('Subir ${ExperienciaInfo.of(tipo).tituloCorto}');
  }

  Future<void> quitarRecurso(String negocioId, ExperienciaTipo tipo) async {
    throw PendienteBackend('Quitar ${ExperienciaInfo.of(tipo).tituloCorto}');
  }

  Future<void> guardarConfigExperiencias(ConfigExperiencias config) async {
    throw const PendienteBackend('Guardar los parámetros de experiencias');
  }
}

/// Parámetros globales de las experiencias (los edita solo el super admin).
class ConfigExperiencias {
  final double radioDesbloqueoDefault;
  final bool revisionObligatoria;
  final bool mostrarSinExperiencias;

  const ConfigExperiencias({
    this.radioDesbloqueoDefault = 50,
    this.revisionObligatoria = true,
    this.mostrarSinExperiencias = true,
  });

  ConfigExperiencias copyWith({double? radioDesbloqueoDefault, bool? revisionObligatoria, bool? mostrarSinExperiencias}) =>
      ConfigExperiencias(
        radioDesbloqueoDefault: radioDesbloqueoDefault ?? this.radioDesbloqueoDefault,
        revisionObligatoria: revisionObligatoria ?? this.revisionObligatoria,
        mostrarSinExperiencias: mostrarSinExperiencias ?? this.mostrarSinExperiencias,
      );
}

// Coordenadas reales aproximadas de Manzanillo; los recursos son marcadores
// de posición ("demo://") solo para que la interfaz muestre cada estado.
const _lugaresDemo = <Lugar>[
  Lugar(
    id: 'demo-audiencia',
    nombre: 'Playa La Audiencia',
    categoriaTexto: 'Playa',
    descripcion: 'Bahía tranquila de aguas claras, ideal para snorkel y para nadar con la familia.',
    direccion: 'Península de Santiago, Manzanillo',
    horario: 'Abierto todo el día',
    portada: 'assets/images/place-playa-audiencia.jpg',
    rating: 4.9,
    totalResenas: 128,
    ubicacion: Coordenadas(19.1006, -104.3399),
    archivo360: 'demo://360',
    arMarcador: 'demo://marcador',
    arGeo: 'demo://geo',
  ),
  Lugar(
    id: 'demo-vigia',
    nombre: 'Cerro del Vigía',
    categoriaTexto: 'Mirador',
    descripcion: 'El mejor mirador de la bahía: vista a los dos lados del puerto al atardecer.',
    direccion: 'Col. Centro, Manzanillo',
    horario: '7:00 – 19:00',
    portada: 'assets/images/place-cerro-vigia.jpg',
    rating: 4.8,
    totalResenas: 96,
    ubicacion: Coordenadas(19.0548, -104.3204),
    archivo360: 'demo://360',
    arGeo: 'demo://geo',
    radioDesbloqueo: 80,
  ),
  Lugar(
    id: 'demo-cuyutlan',
    nombre: 'Laguna de Cuyutlán',
    categoriaTexto: 'Recreación',
    descripcion: 'Laguna costera con manglares y aves migratorias; recorridos en lancha.',
    direccion: 'Carretera Manzanillo – Cuyutlán',
    horario: '8:00 – 17:00',
    portada: 'assets/images/place-laguna-cuyutlan.jpg',
    rating: 4.6,
    totalResenas: 54,
    ubicacion: Coordenadas(19.0205, -104.2550),
    arMarcador: 'demo://marcador',
  ),
  Lugar(
    id: 'demo-pezvela',
    nombre: 'Monumento al Pez Vela',
    categoriaTexto: 'Cultura',
    descripcion: 'Escultura emblemática del malecón, símbolo de la "Capital mundial del pez vela".',
    direccion: 'Jardín Álvaro Obregón, Centro',
    horario: 'Abierto todo el día',
    portada: 'assets/images/hero-manzanillo.jpg',
    rating: 4.7,
    totalResenas: 210,
    ubicacion: Coordenadas(19.0530, -104.3160),
    arMarcador: 'demo://marcador',
    arGeo: 'demo://geo',
    radioDesbloqueo: 40,
  ),
  Lugar(
    id: 'demo-miramar',
    nombre: 'Playa Miramar',
    categoriaTexto: 'Playa',
    descripcion: 'Oleaje ideal para surf y bodyboard, con palapas y restaurantes frente al mar.',
    direccion: 'Blvd. Miguel de la Madrid, Miramar',
    horario: 'Abierto todo el día',
    portada: 'assets/images/place-playa-audiencia.jpg',
    rating: 4.5,
    totalResenas: 77,
    ubicacion: Coordenadas(19.1185, -104.3930),
  ),
  Lugar(
    id: 'demo-mariscos',
    nombre: 'Mariscos El Faro',
    categoriaTexto: 'Restaurante de mariscos',
    descripcion: 'Ceviches, pescado zarandeado y aguachiles frente a la bahía de Santiago.',
    direccion: 'Playa Santiago, Manzanillo',
    horario: '12:00 – 22:00',
    telefono: '314 000 0000',
    portada: 'assets/images/hero-manzanillo.jpg',
    rating: 4.4,
    totalResenas: 41,
    ubicacion: Coordenadas(19.0990, -104.3620),
    archivo360: 'demo://360',
  ),
];
