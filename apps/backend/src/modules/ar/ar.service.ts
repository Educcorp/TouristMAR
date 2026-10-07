import { randomUUID } from 'crypto'
import type { ar_contenido_enum } from '@prisma/client'
import { prisma } from '../../config/prisma'
import { supabase, AR_MARCADORES_BUCKET } from '../../config/supabase'
import { withDbGuard } from '../../config/db-guard'

export class ArMarcadorNotFoundError extends Error {}
export class ArImagenInvalidaError extends Error {}
export class ArNombreDuplicadoError extends Error {}

/// Solo PNG y JPG: son los únicos formatos que `UnityWebRequestTexture` sabe
/// decodificar en Android/iOS. WEBP/GIF se verían bien en el panel pero Unity
/// no podría convertirlos en textura y el marcador nunca se registraría.
const ALLOWED_MARCADOR_TYPES: Record<string, string> = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
}

type ImagenInput = { buffer: Buffer; mimetype: string }

export interface ArMarcadorInput {
  nombre: string
  titulo: string
  texto: string
  anchoMetros?: number | null
  negocioId?: string | null
  tipoContenido?: ar_contenido_enum
  contenidoUrl?: string | null
  activo?: boolean
}

/// Lo que Unity necesita al arrancar la cámara: marcadores activos que no
/// pertenezcan a un negocio sin aprobar (un negocio pendiente o rechazado no
/// debe aparecer en la app pública, tampoco en AR).
/// [negocioId] = solo los marcadores de ese lugar (la escena de marcadores
/// abierta desde la RA por geolocalización de un lugar).
export async function listPublicMarcadores(negocioId?: string) {
  return withDbGuard(() =>
    prisma.arMarcador.findMany({
      where: {
        activo: true,
        OR: [{ negocioId: null }, { negocio: { estado: 'aprobado' } }],
        ...(negocioId ? { negocioId } : {}),
      },
      include: { negocio: { select: { nombre: true } } },
      orderBy: { createdAt: 'asc' },
    }),
  )
}

export async function listAllMarcadores() {
  return withDbGuard(() =>
    prisma.arMarcador.findMany({
      include: { negocio: { select: { nombre: true } }, _count: { select: { escaneos: true } } },
      orderBy: { createdAt: 'desc' },
    }),
  )
}

// El bucket se crea solo la primera vez que hace falta, así no hay que
// acordarse de darlo de alta a mano en Supabase en cada entorno.
let bucketReady: Promise<void> | null = null

function ensureBucket() {
  bucketReady ??= (async () => {
    const { error } = await supabase.storage.getBucket(AR_MARCADORES_BUCKET)
    if (!error) return
    const { error: createError } = await supabase.storage.createBucket(AR_MARCADORES_BUCKET, { public: true })
    if (createError && !/already exists/i.test(createError.message)) {
      bucketReady = null
      throw new Error(`No se pudo preparar el almacenamiento de marcadores: ${createError.message}`)
    }
  })()
  return bucketReady
}

async function uploadImagen(marcadorId: string, file: ImagenInput) {
  await ensureBucket()

  // Un archivo fijo por marcador: reemplazar la imagen sobreescribe la
  // anterior en el mismo lugar en vez de acumular archivos huérfanos.
  const path = `${marcadorId}/marcador`
  const { error } = await supabase.storage
    .from(AR_MARCADORES_BUCKET)
    .upload(path, file.buffer, { contentType: file.mimetype, upsert: true })
  if (error) {
    throw new Error(`No se pudo subir la imagen: ${error.message}`)
  }

  // Cache-bust: la ruta no cambia entre reemplazos, y Unity (igual que el
  // navegador) usa la URL completa para decidir si vuelve a descargar.
  const { data } = supabase.storage.from(AR_MARCADORES_BUCKET).getPublicUrl(path)
  return { path, url: `${data.publicUrl}?v=${Date.now()}` }
}

function assertImagen(file: ImagenInput) {
  if (!ALLOWED_MARCADOR_TYPES[file.mimetype]) {
    throw new ArImagenInvalidaError('Formato no soportado para un marcador AR (usa PNG o JPG)')
  }
}

/// `nombre` es el identificador con el que Unity registra la imagen en su
/// biblioteca y la reconoce al detectarla: dos marcadores con el mismo
/// nombre se pisarían. La comparación ignora mayúsculas por si acaso, aunque
/// el controller ya los normaliza a minúsculas.
async function assertNombreLibre(nombre: string | undefined, exceptoId?: string) {
  if (!nombre) return
  const otro = await prisma.arMarcador.findFirst({
    where: { nombre: { equals: nombre, mode: 'insensitive' }, ...(exceptoId ? { NOT: { id: exceptoId } } : {}) },
    select: { id: true },
  })
  if (otro) {
    throw new ArNombreDuplicadoError(`Ya existe un marcador con el nombre "${nombre}"`)
  }
}

async function assertNegocioExiste(negocioId: string | null | undefined) {
  if (!negocioId) return
  const negocio = await prisma.negocioProfile.findUnique({ where: { id: negocioId }, select: { id: true } })
  if (!negocio) {
    throw new ArMarcadorNotFoundError('No se encontró el negocio indicado')
  }
}

export async function createMarcador(input: ArMarcadorInput, file: ImagenInput, adminId: string) {
  assertImagen(file)

  return withDbGuard(async () => {
    await assertNegocioExiste(input.negocioId)
    await assertNombreLibre(input.nombre)

    // El id se decide antes de subir la imagen porque forma parte de la ruta
    // en Storage.
    const id = randomUUID()
    const imagen = await uploadImagen(id, file)

    return prisma.arMarcador.create({
      data: { id, ...input, imagenUrl: imagen.url, imagenPath: imagen.path, creadoPor: adminId },
      include: { negocio: { select: { nombre: true } }, _count: { select: { escaneos: true } } },
    })
  })
}

export async function updateMarcador(id: string, input: Partial<ArMarcadorInput>) {
  return withDbGuard(async () => {
    const existing = await prisma.arMarcador.findUnique({ where: { id } })
    if (!existing) {
      throw new ArMarcadorNotFoundError('No se encontró ese marcador')
    }
    await assertNegocioExiste(input.negocioId)
    await assertNombreLibre(input.nombre, id)

    return prisma.arMarcador.update({
      where: { id },
      data: input,
      include: { negocio: { select: { nombre: true } }, _count: { select: { escaneos: true } } },
    })
  })
}

export async function replaceMarcadorImagen(id: string, file: ImagenInput) {
  assertImagen(file)

  return withDbGuard(async () => {
    const existing = await prisma.arMarcador.findUnique({ where: { id } })
    if (!existing) {
      throw new ArMarcadorNotFoundError('No se encontró ese marcador')
    }

    const imagen = await uploadImagen(id, file)
    return prisma.arMarcador.update({
      where: { id },
      data: { imagenUrl: imagen.url, imagenPath: imagen.path },
      include: { negocio: { select: { nombre: true } }, _count: { select: { escaneos: true } } },
    })
  })
}

export async function deleteMarcador(id: string) {
  return withDbGuard(async () => {
    const existing = await prisma.arMarcador.findUnique({ where: { id } })
    if (!existing) {
      throw new ArMarcadorNotFoundError('No se encontró ese marcador')
    }

    await prisma.arMarcador.delete({ where: { id } })
    // Si falla el borrado en Storage no se revierte nada: el marcador ya no
    // existe para la app, y un archivo suelto no rompe nada.
    await supabase.storage.from(AR_MARCADORES_BUCKET).remove([existing.imagenPath])
  })
}

/// Unity solo conoce el `nombre` del marcador (es lo único que viaja en el
/// JSON público), así que el escaneo se registra por nombre.
export async function registerEscaneo(nombre: string, userId: string | undefined, plataforma: string | undefined) {
  return withDbGuard(async () => {
    const marcador = await prisma.arMarcador.findUnique({ where: { nombre }, select: { id: true, activo: true } })
    if (!marcador || !marcador.activo) {
      throw new ArMarcadorNotFoundError('No se encontró ese marcador')
    }
    await prisma.arEscaneo.create({
      data: { marcadorId: marcador.id, userId: userId ?? null, plataforma: plataforma ?? null },
    })
  })
}
