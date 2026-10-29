import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

/// Lugares reales de Manzanillo, Colima investigados para poblar el mapa con
/// contenido real (no inventado) mientras el directorio de negocios sigue
/// creciendo. Cada uno trae en un comentario de dónde sale cada dato que se
/// pudo confirmar — varios campos quedan en null a propósito porque la
/// búsqueda no encontró una fuente confiable para ellos (mejor vacío que un
/// dato inventado): coordenadas exactas (se
/// recomienda ponerlas a mano desde "Elegir en el mapa" en el panel admin,
/// que ya sugiere la dirección aproximada al soltar el pin), teléfono/sitio
/// web/horario cuando las fuentes se contradecían entre sí, y portada
/// cuando no se encontró una foto de uso libre que de verdad fuera de ese
/// lugar.
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
    latitud: null,
    longitud: null,
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
    portada: null,
    latitud: null,
    longitud: null,
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
    portada: null,
    latitud: null,
    longitud: null,
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
    portada: null,
    latitud: null,
    longitud: null,
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
    portada: null,
    latitud: null,
    longitud: null,
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
    portada: null,
    latitud: null,
    longitud: null,
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
    latitud: null,
    longitud: null,
  },
  {
    nombre: 'Cerro de la Cruz',
    categoria: 'Mirador',
    descripcion:
      'Caminata corta (de unos 15 minutos) pero exigente hasta un mirador con vista de 360° de Manzanillo: la ' +
      'bahía, la Laguna de Cuyutlán y el puerto interior de San Pedrito. Se llega por un sendero que conecta con el ' +
      'Mirador El Vigía.',
    direccion: 'Centro Histórico, Manzanillo, Colima (acceso por el sendero desde el Mirador El Vigía)',
    telefono: null,
    sitioWeb: null,
    horario: null,
    portada: null,
    latitud: null,
    longitud: null,
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
    portada: null,
    latitud: null,
    longitud: null,
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
    latitud: null,
    longitud: null,
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
    latitud: null,
    longitud: null,
  },
  {
    nombre: 'Coco Loco',
    categoria: 'Club nocturno',
    descripcion: 'Bar dentro de la zona de Las Hadas, en la Península de Santiago.',
    direccion: 'Las Hadas, Península de Santiago, 28867 Manzanillo, Colima',
    telefono: null,
    sitioWeb: null,
    horario: null,
    portada: null,
    latitud: null,
    longitud: null,
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

  console.log(`Listo: ${creados} lugares creados, ${actualizados} actualizados (cuenta: ${superAdmin.email}).`)
}

main()
  .catch((err) => {
    console.error(err)
    process.exitCode = 1
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
