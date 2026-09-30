import 'recorridos_service.dart' show normalizarNombre;

/// Las playas que conoce la RA por ubicación. Espejo de `listaPlayas` en
/// ar-module ControladorPlayas.cs: los nombres tienen que coincidir EXACTO,
/// porque es lo que se le manda a Unity.
const playasConRA = [
  'Playa El Paraíso',
  'Cuyutlán',
  'Playa Miramar',
  'Playa los Arcos',
  'Playa Las Palmitas',
  'Playa La Boquita',
  'Playa Olas Altas',
  'Playa La Audiencia',
  'Playa Salagua',
  'Playa Las Brisas',
  'Playa Perla',
  'Playa Club de Yates',
  'Playa Azul',
  'Playa de las Quinceañeras',
  'Playa San Pedrito',
  'Playa Vida del Mar',
  'Estrecho Peña Blanca',
];

/// La playa de la RA por ubicación que corresponde a este lugar, o `null` si
/// no tiene. Solo cuenta el mismo nombre ("Playa La Audiencia" ↔ "La
/// Audiencia"): nunca se toma otra playa parecida ni se ofrece otra en su lugar.
String? playaParaLugar(String nombreLugar) {
  final lugar = normalizarNombre(nombreLugar);
  if (lugar.isEmpty) return null;
  for (final p in playasConRA) {
    if (normalizarNombre(p) == lugar) return p;
  }
  return null;
}

/// Aviso para un lugar que todavía no tiene RA por ubicación.
String sinRaUbicacion(String lugarNombre) =>
    '$lugarNombre por el momento no cuenta con realidad aumentada por ubicación.';
