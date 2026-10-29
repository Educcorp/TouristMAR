import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

/// Lugares reales de Manzanillo, Colima investigados para poblar el mapa con
/// contenido real (no inventado) mientras el directorio de negocios sigue
/// creciendo. Cada uno trae en un comentario de dónde sale cada dato que se
/// pudo confirmar — varios campos quedan en null a propósito porque la
/// búsqueda no encontró una fuente confiable para ellos (mejor vacío que un
/// dato inventado): teléfono/sitio web/horario cuando las fuentes se
/// contradecían entre sí, y portada cuando no se encontró una foto de uso
/// libre que de verdad fuera de ese lugar.
///
/// Las coordenadas son necesarias: `GET /api/lugares` (el mapa y los
/// "Destacados" del inicio del visitante) solo muestra negocios aprobados
/// CON latitud/longitud (ver `listLugaresPublicos` en lugares.service.ts) —
/// sin coordenadas, un lugar aprobado existe en la base pero no aparece en
/// ninguna pantalla pública. Se geocodificaron las direcciones de arriba con
/// Nominatim/OpenStreetMap (mismo proveedor que ya usa el mapa de la app);
/// donde no hubo ningún resultado confiable (Iguanario Archundia) se dejó la
/// coordenada en null en vez de usar un punto dudoso — se recomienda
/// ponerla a mano desde "Elegir en el mapa" en el panel admin, que ya
/// sugiere la dirección aproximada al soltar el pin. Por la misma razón se
/// reemplazó "Cerro de la Cruz" por "Mirador Ventanas" en la categoría
/// Mirador: no se pudo verificar ni coordenadas ni foto confiables para el
/// primero, y el segundo sí tiene ambas.
///
/// No se pudo armar un "Club de playa" con datos verificables: lo más
/// cercano (Sun Club/Club de Playa en Plaza Las Glorias, Pata Salada Beach
/// Bar) no tenía dirección ni horario confirmables en ninguna fuente — se
/// dejó fuera en vez de inventar esos datos. Ver el resumen que acompaña
/// este script para más detalle.
const lugares = [
  // --- Playa ---------------------------------------------------------------
  {
    nombre: 'Playa La Audiencia',
    categoria: 'Playa',
    descripcion:
      'Playa de aguas tranquilas en una ensenada de la Península de Santiago, en la bahía de Manzanillo. ' +
      'Popular para nadar y para deportes acuáticos como esquí acuático, snorkel y buceo gracias a su oleaje suave. ' +
      'Alrededor hay pequeños restaurantes y opciones de hospedaje.',
    direccion: 'Península de Santiago, Manzanillo, Colima (acceso por Av. La Audiencia)',
    telefono: null,
    sitioWeb: null,
    horario: null,
    portada: 'assets/images/place-playa-audiencia.jpg',
    // Geocodificado (Nominatim/OpenStreetMap) a partir de la dirección de arriba.
    latitud: 19.1047,
    longitud: -104.3501,
  },
  {
    nombre: 'Playa Miramar',
    categoria: 'Playa',
    descripcion:
      'Playa de la bahía de Santiago, entre Playa Olas Altas y Playa Boutique. Es la playa de oleaje tipo "beach ' +
      'break" más cercana al centro de la ciudad, con olas que suelen favorecer a surfistas principiantes e ' +
      'intermedios; se pueden rentar tablas con los vendedores de la zona. Los fines de semana se llena de turismo ' +
      'nacional.',
    direccion: 'Bahía de Santiago, Manzanillo, Colima',
    telefono: null,
    sitioWeb: null,
    horario: null,
    // CC BY-SA 2.0, Comisión Mexicana de Filmaciones, vía Wikimedia Commons:
    // https://commons.wikimedia.org/wiki/File:Playa_Miramar,_Colima_-_Miramar_beach_(31664973424).jpg
    portada: 'https://upload.wikimedia.org/wikipedia/commons/7/71/Playa_Miramar%2C_Colima_-_Miramar_beach_%2831664973424%29.jpg',
    latitud: 19.1185,
    longitud: -104.3861,
  },

  // --- Restaurante -----------------------------------------------------------
  {
    nombre: "Juanito's",
    categoria: 'Restaurante',
    descripcion:
      'Restaurante de comida mexicana y estadounidense en la colonia Santiago, con más de cuatro décadas operando ' +
      'bajo la misma familia. La carta incluye chilaquiles colimenses, hamburguesas, malteadas y costillas a la ' +
      'barbacoa.',
    direccion: 'Blvd. Miguel de la Madrid km 14, Col. Santiago, Manzanillo, Colima',
    telefono: '+52 314 333 1388',
    sitioWeb: null,
    horario: 'Lunes a domingo, 8:00 a 17:00 (confirmar vigencia)',
    // Foto real de la fachada (letrero "Juanito's" visible), vía Zona
    // Turística: https://www.zonaturistica.com/restaurante/2108/juanitos-manzanillo.html
    portada: 'https://www.zonaturistica.com/files/restaurantes/2108/R1_2108.jpg',
    latitud: 19.1149,
    longitud: -104.3465,
  },
  {
    nombre: 'Legazpi Restaurant & Bar',
    categoria: 'Restaurante',
    descripcion:
      'Restaurante de alta cocina internacional dentro del resort Las Hadas, con música de piano en vivo. ' +
      'Reservación recomendada.',
    direccion: 'Vista Hermosa S/N, Las Hadas, Península de Santiago, 28867 Manzanillo, Colima',
    telefono: null,
    sitioWeb: null,
    horario: null,
    // Foto real de una mesa puesta con el plato grabado "Legazpi" — confirma
    // que es este restaurante y no otro del resort. Vía En Primeur Club:
    // https://www.enprimeurclub.com/restaurants/legazpi-restaurant-and-bar-manzanillo-restaurant
    portada:
      'https://cdn.enprimeurclub.com/storage/v1/object/public/images/restaurants/9eb5371d-1a27-4441-8ad1-7ca096bd9899/hero1.jpg',
    // Aproximado: Nominatim no tiene el restaurante como punto propio, esto
    // ubica la zona de Las Hadas/La Punta donde está el resort.
    latitud: 19.1008,
    longitud: -104.3506,
  },

  // --- Hotel -----------------------------------------------------------------
  {
    nombre: 'Barceló Karmina Palace',
    categoria: 'Hotel',
    descripcion:
      'Hotel todo incluido frente al mar en la Península de Santiago, con 324 suites (la mayoría con balcón y ' +
      'vista panorámica), spa, piscinas estilo laguna, gimnasio y salones para grupos de hasta 1,200 personas. ' +
      'Cerca de Playa La Audiencia.',
    direccion: 'Av. Vista Hermosa 13, Península de Santiago, 28867 Manzanillo, Colima',
    telefono: null,
    sitioWeb: 'https://www.barcelo.com/es-mx/hoteles/manzanillo/hotel-barcelo-karmina-palace-deluxe/',
    horario: null,
    // CC BY-SA 3.0, Jack Borno, vía Wikimedia Commons (foto de 2006, el
    // hotel pudo renovarse desde entonces):
    // https://commons.wikimedia.org/wiki/File:Karmina_Palace_Pools_-_panoramio.jpg
    portada: 'https://upload.wikimedia.org/wikipedia/commons/1/18/Karmina_Palace_Pools_-_panoramio.jpg',
    // Geocodificado: coincide con el punto que OpenStreetMap ya tiene
    // registrado para "Barceló Karmina Palace Deluxe".
    latitud: 19.1054,
    longitud: -104.3421,
  },
  {
    nombre: 'Hotel Colonial',
    categoria: 'Hotel',
    descripcion:
      'Hotel de 3 estrellas en el Centro Histórico, a menos de un kilómetro del malecón, en un edificio con ' +
      'decoración de azulejos mexicanos pintados a mano. Tiene restaurante, wifi gratuito, recepción 24 horas con ' +
      'información turística y estacionamiento privado.',
    direccion: 'Calle Fco. Bocanegra #28, Centro Histórico, Manzanillo, Colima (verificar numeración exacta)',
    telefono: null,
    sitioWeb: null,
    horario: null,
    // Foto real de la fachada, vía Zona Turística:
    // https://www.zonaturistica.com/hotel/5639/colonial-manzanillo.html
    portada: 'https://www.zonaturistica.com/hotel_files/5639/F1_5639.jpg',
    // Geocodificado a partir de la dirección; queda a ~100m del Monumento al
    // Pez Vela, consistente con la referencia "a menos de 0.1 mi" encontrada.
    latitud: 19.0532,
    longitud: -104.3176,
  },

  // --- Mirador ---------------------------------------------------------------
  {
    nombre: 'Mirador El Vigía (Cerro del Vigía)',
    categoria: 'Mirador',
    descripcion:
      'Mirador en lo alto de una de las colinas del Centro Histórico de Manzanillo, con vista amplia del puerto y ' +
      'de las aguas tranquilas de la bahía. Desde aquí sale un sendero hacia el Cerro de la Cruz.',
    direccion: 'Calle 21 de Marzo, Centro Histórico, Manzanillo, Colima',
    telefono: null,
    sitioWeb: null,
    horario: null,
    portada: 'assets/images/place-cerro-vigia.jpg',
    // Geocodificado a partir de la dirección (Calle 21 de Marzo).
    latitud: 19.0499,
    longitud: -104.3174,
  },
  {
    // Reemplaza a "Cerro de la Cruz": no se pudo verificar ni una foto real
    // ni coordenadas confiables para ese mirador (ver el historial del
    // script). Mirador Ventanas sí tiene ambas cosas confirmadas.
    nombre: 'Mirador Ventanas',
    categoria: 'Mirador',
    descripcion:
      'Mirador sobre la carretera de Manzanillo a Campos, llamado así por la formación rocosa que enmarca el mar ' +
      'como una ventana. Recomendado para fotografiar el amanecer o el atardecer sobre el Pacífico.',
    direccion: 'Carretera de Manzanillo a Campos, Manzanillo, Colima',
    telefono: null,
    sitioWeb: null,
    horario: null,
    // Foto real del lugar (amanecer entre las rocas), vía Zona Turística:
    // https://www.zonaturistica.com/que-hacer-en/colima/manzanillo/mirador-ventanas
    portada: 'https://www.zonaturistica.com/files/atractivos/110/A1_110.jpg',
    // Coordenadas de la misma fuente (enlace "Cómo llegar" de la página).
    latitud: 19.0314,
    longitud: -104.3334,
  },

  // --- Cultura -----------------------------------------------------------------
  {
    nombre: 'Jardín Álvaro Obregón',
    categoria: 'Cultura',
    descripcion:
      'Plaza principal de Manzanillo, frente al malecón, con un kiosco central, árboles floreados y una fuente. ' +
      'Históricamente conocida como Plaza Galván. Por las tardes suele haber actividades familiares.',
    direccion: 'Centro Histórico, Manzanillo, Colima',
    telefono: null,
    sitioWeb: null,
    horario: null,
    // CC BY-SA 3.0, Yaomautzin Ohtokani Olvera Lara, vía Wikimedia Commons
    // (foto de 2007, la fuente/plaza pudo renovarse desde entonces):
    // https://commons.wikimedia.org/wiki/File:Manzanillo_fuente.JPG
    portada: 'https://upload.wikimedia.org/wikipedia/commons/3/32/Manzanillo_fuente.JPG',
    // Geocodificado: coincide con el punto que OpenStreetMap ya tiene
    // registrado para "Jardín Álvaro Obregón".
    latitud: 19.054,
    longitud: -104.3169,
  },
  {
    nombre: 'Monumento al Pez Vela',
    categoria: 'Cultura',
    descripcion:
      'Escultura metálica de gran tamaño (fuentes la describen entre 25 y 30 metros de alto) obra del artista ' +
      'mexicano Sebastián, en el malecón del Centro Histórico. Representa un pez vela saltando con la aleta ' +
      'dorsal desplegada, en honor al título de Manzanillo como "Capital Mundial del Pez Vela" por la abundancia ' +
      'de esta especie en sus costas (más común entre junio y octubre).',
    direccion: 'Malecón, Centro Histórico, Manzanillo, Colima',
    telefono: null,
    sitioWeb: null,
    horario: null,
    // CC BY-SA 3.0, Wiper México, vía Wikimedia Commons:
    // https://commons.wikimedia.org/wiki/File:Pez_Vela_en_malecon_-_panoramio.jpg
    portada: 'https://upload.wikimedia.org/wikipedia/commons/8/82/Pez_Vela_en_malecon_-_panoramio.jpg',
    // Geolocalización EXIF original de la foto de Commons (verificar con pin propio).
    latitud: 19.0538,
    longitud: -104.3166,
  },

  // --- Recreación ------------------------------------------------------------
  {
    nombre: 'Centro Ecológico de Cuyutlán (El Tortugario)',
    categoria: 'Recreación',
    descripcion:
      'Centro de conservación de tortugas marinas (golfina, negra y laúd) cerca de la Laguna de Cuyutlán, con más ' +
      'de 2 millones de crías liberadas en más de 30 años de trabajo. También protege iguanas y cocodrilos. ' +
      'Ofrece recorridos en lancha por los manglares para ver aves y fauna local, y talleres ambientales. Las ' +
      'liberaciones de crías son por temporada (fechas varían según la fuente: confirmar antes de ir).',
    direccion: 'Cerca de Cuyutlán, Municipio de Armería, Colima',
    telefono: null,
    sitioWeb: null,
    horario: null,
    portada: 'assets/images/place-laguna-cuyutlan.jpg',
    // Aproximado: geocodificado al pueblo de Cuyutlán — las fuentes ubican
    // el centro ecológico entre 3 y 4 km de ahí, pero no coinciden en
    // dirección exacta.
    latitud: 18.92,
    longitud: -104.0696,
  },
  {
    nombre: 'Iguanario Archundia',
    categoria: 'Recreación',
    descripcion:
      'Santuario de iguanas en el centro de Manzanillo, fundado por Ramón Archundia hace más de cuatro décadas. ' +
      'Alberga varios cientos de iguanas además de otros animales donados (mapaches, tejones, tortugas). La ' +
      'entrada es libre y el lugar se sostiene con donativos; se puede dar de comer a las iguanas bajo supervisión ' +
      'del personal.',
    direccion: 'Centro, Manzanillo, Colima (confirmar dirección exacta: las fuentes varían entre "Centro" y "Valle Dorado")',
    telefono: null,
    sitioWeb: null,
    horario: null,
    portada: null,
    // Sin coordenadas: el geocodificador no encontró este lugar (es un
    // sitio pequeño, sin punto propio en OpenStreetMap). Ponerlas a mano
    // desde "Elegir en el mapa" en el panel admin.
    latitud: null,
    longitud: null,
  },

  // --- Club nocturno -----------------------------------------------------------
  {
    nombre: 'Colima Bay Café',
    categoria: 'Club nocturno',
    descripcion:
      'Bar y restaurante con ambiente de fiesta, DJ y música electrónica, uno de los centros nocturnos frecuentados ' +
      'tanto por locales como por turistas en el boulevard costero.',
    direccion: 'Blvd. Costero Miguel de la Madrid 921, 28860 Manzanillo, Colima',
    telefono: null,
    sitioWeb: null,
    horario: null,
    portada: null,
    // Geocodificado a partir de la dirección (boulevard costero).
    latitud: 19.1195,
    longitud: -104.3841,
  },
  {
    nombre: 'Coco Loco',
    categoria: 'Club nocturno',
    descripcion: 'Bar dentro de la zona de Las Hadas, en la Península de Santiago.',
    direccion: 'Las Hadas, Península de Santiago, 28867 Manzanillo, Colima',
    telefono: null,
    sitioWeb: null,
    horario: null,
    // Foto de su ficha en En Primeur Club (vista de alberca/palapa junto a
    // la bahía, consistente con la zona de Las Hadas; sin letrero visible
    // que lo confirme al 100%, pero es la foto que el propio directorio usa
    // para este negocio): https://www.enprimeurclub.com/bars/coco-loco-manzanillo-bar
    portada: 'https://cdn.enprimeurclub.com/storage/v1/object/public/images/bars/ff312bbd-d4df-4c15-9cfc-de05fadfa00a/hero1.jpg',
    // Aproximado: Nominatim no tiene el bar como punto propio, esto ubica la
    // zona de Las Hadas/La Punta.
    latitud: 19.1008,
    longitud: -104.3506,
  },
] as const

async function main() {
  const superAdmin = await prisma.user.findFirst({
    where: { rol: 'super_admin' },
    orderBy: { createdAt: 'asc' },
    select: { id: true, email: true },
  })
  if (!superAdmin) {
    throw new Error(
      'No hay ninguna cuenta super_admin en esta base de datos — crea una antes de correr el seed ' +
        '(estos lugares se guardan a su nombre, igual que los que registra el admin desde "Mapa y RA").',
    )
  }

  // Lugares que un seed anterior creó y que este reemplazó por otro mejor
  // (ver el comentario junto al nuevo nombre en `lugares`) — se borran para
  // no dejar el reemplazado como un duplicado huérfano en la base.
  const reemplazados = ['Cerro de la Cruz']
  const { count: borrados } = await prisma.negocioProfile.deleteMany({
    where: { userId: superAdmin.id, nombre: { in: reemplazados } },
  })

  let creados = 0
  let actualizados = 0
  for (const lugar of lugares) {
    const existente = await prisma.negocioProfile.findFirst({
      where: { userId: superAdmin.id, nombre: lugar.nombre },
      select: { id: true },
    })
    if (existente) {
      await prisma.negocioProfile.update({ where: { id: existente.id }, data: lugar })
      actualizados++
    } else {
      await prisma.negocioProfile.create({
        data: { ...lugar, userId: superAdmin.id, estado: 'aprobado', revisadoPor: superAdmin.id, revisadoEn: new Date() },
      })
      creados++
    }
  }

  console.log(
    `Listo: ${creados} lugares creados, ${actualizados} actualizados, ${borrados} reemplazados-borrados ` +
      `(cuenta: ${superAdmin.email}).`,
  )
}

main()
  .catch((err) => {
    console.error(err)
    process.exitCode = 1
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
