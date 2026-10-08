import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lugar.dart';
import 'auth_service.dart' show apiUrl, AuthError, crearClienteHttp;
import 'session_storage.dart';

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
/// [listarPublicos] ya trae los negocios aprobados con `latitud`/`longitud`
/// desde `GET /api/lugares` (hoy son pocos: la mayoría de los negocios
/// existentes todavía no tiene coordenadas cargadas) y completa el resto del
/// catálogo con el listado de ejemplo, para no perder la vitrina completa
/// mientras el resto de los negocios no tenga su pin. Falta todavía:
///   - `PUT/DELETE /api/auth/profile/negocios/:id/experiencias/:tipo` (multipart)
///   - `PUT  /api/admin/experiencias/config`   { radioDesbloqueo, ... }
class LugaresService {
  const LugaresService();

  bool get usaDatosDemo => true;

  /// Trae los negocios reales con pin ya cargado y completa el resto del
  /// catálogo con los lugares de ejemplo (sin duplicar por nombre). Si el
  /// backend no responde, se sigue mostrando el catálogo de ejemplo — el
  /// mapa nunca debe quedar vacío por un error de red pasajero.
  Future<List<Lugar>> listarPublicos() async {
    var reales = const <Lugar>[];
    final cliente = crearClienteHttp();
    try {
      final res = await cliente.get(Uri.parse('$apiUrl/lugares'));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        reales = (data['lugares'] as List)
            .map((j) => Lugar.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Sin conexión con el backend: se sigue mostrando el catálogo de ejemplo.
    } finally {
      cliente.close();
    }

    final nombresReales = reales.map((l) => l.nombre).toSet();
    return [...reales, ..._lugaresDemo.where((l) => !nombresReales.contains(l.nombre))];
  }

  /// El dueño fija el pin de su negocio.
  Future<void> guardarUbicacion(String negocioId, Coordenadas ubicacion) async {
    final token = SessionStorage.token;
    if (token == null) throw const AuthError('Tu sesión expiró. Vuelve a iniciar sesión.');
    final cliente = crearClienteHttp();
    final http.Response res;
    try {
      res = await cliente.patch(
        Uri.parse('$apiUrl/auth/profile/negocios/$negocioId'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'latitud': ubicacion.lat, 'longitud': ubicacion.lng}),
      );
    } finally {
      cliente.close();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw const AuthError('No se pudo guardar la ubicación');
    }
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
    // Sin calificación: un lugar de ejemplo no tiene reseñas reales.
    rating: 0,
    totalResenas: 0,
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
    // Sin calificación: un lugar de ejemplo no tiene reseñas reales.
    rating: 0,
    totalResenas: 0,
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
    // Sin calificación: un lugar de ejemplo no tiene reseñas reales.
    rating: 0,
    totalResenas: 0,
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
    // Sin calificación: un lugar de ejemplo no tiene reseñas reales.
    rating: 0,
    totalResenas: 0,
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
    // Sin calificación: un lugar de ejemplo no tiene reseñas reales.
    rating: 0,
    totalResenas: 0,
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
    // Sin calificación: un lugar de ejemplo no tiene reseñas reales.
    rating: 0,
    totalResenas: 0,
    ubicacion: Coordenadas(19.0990, -104.3620),
    archivo360: 'demo://360',
  ),
];
