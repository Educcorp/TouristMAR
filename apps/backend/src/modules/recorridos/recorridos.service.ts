import { randomUUID } from 'crypto'
import { prisma } from '../../config/prisma'
import { supabase, RECORRIDOS_360_BUCKET } from '../../config/supabase'
import { withDbGuard } from '../../config/db-guard'
import { procesarEscena } from './escena-imagen'

export class RecorridoNotFoundError extends Error {}
export class RecorridoNombreDuplicadoError extends Error {}
export class EnlaceInvalidoError extends Error {}

/// Un recorrido tiene de 1 a 32 escenarios (casillas "Escenario 1"…"32"). El
/// Escenario 1 es por donde entra el turista. Mismo límite que el CHECK de
/// `recorrido_360_escenas.orden` en la base.
export const MAX_ESCENARIOS = 32

export interface RecorridoInput {
  nombre: string
  titulo: string
  texto: string
  negocioId?: string | null
  activo?: boolean
  latitud?: number | null
  longitud?: number | null
}

export interface EscenaInfo {
  titulo?: string
  descripcion?: string
  yawInicial?: number
}

/// Flecha tal como la manda el panel: el destino es la casilla (1–32) de
/// otro escenario del mismo recorrido.
export interface EnlaceInput {
  destino: number
  yaw: number
  pitch?: number
  etiqueta?: string
}

const escenasOrdenadas = {
  orderBy: { orden: 'asc' as const },
  include: {
    enlaces: {
      include: { destino: { select: { orden: true } } },
      orderBy: { destino: { orden: 'asc' as const } },
    },
  },
}

const includeAdmin = {
  negocio: { select: { nombre: true } },
  escenas: escenasOrdenadas,
}

/// Lo que ve el turista: recorridos activos, con al menos un escenario, que no
/// pertenezcan a un negocio sin aprobar (igual que los marcadores).
export async function listPublicRecorridos(negocioId?: string) {
  return withDbGuard(() =>
    prisma.recorrido360.findMany({
      where: {
        activo: true,
        escenas: { some: {} },
        ...(negocioId ? { negocioId } : {}),
        OR: [{ negocioId: null }, { negocio: { estado: 'aprobado' } }],
      },
      include: { escenas: escenasOrdenadas },
      orderBy: { createdAt: 'asc' },
    }),
  )
}

export async function getPublicRecorrido(nombre: string) {
  return withDbGuard(async () => {
    const recorrido = await prisma.recorrido360.findUnique({
      where: { nombre },
      include: { escenas: escenasOrdenadas, negocio: { select: { estado: true } } },
    })
    const visible =
      recorrido &&
      recorrido.activo &&
      recorrido.escenas.length > 0 &&
      (!recorrido.negocio || recorrido.negocio.estado === 'aprobado')
    if (!visible) {
      throw new RecorridoNotFoundError('No se encontró ese recorrido')
    }
    return recorrido
  })
}

export async function listAllRecorridos() {
  return withDbGuard(() =>
    prisma.recorrido360.findMany({ include: includeAdmin, orderBy: { createdAt: 'desc' } }),
  )
}

// El bucket se crea solo la primera vez que hace falta (mismo criterio que
// el de marcadores AR).
let bucketReady: Promise<void> | null = null

function ensureBucket() {
  bucketReady ??= (async () => {
    const { error } = await supabase.storage.getBucket(RECORRIDOS_360_BUCKET)
    if (!error) return
    const { error: createError } = await supabase.storage.createBucket(RECORRIDOS_360_BUCKET, { public: true })
    if (createError && !/already exists/i.test(createError.message)) {
      bucketReady = null
      throw new Error(`No se pudo preparar el almacenamiento de recorridos: ${createError.message}`)
    }
  })()
  return bucketReady
}

async function subirArchivo(path: string, buffer: Buffer) {
  const { error } = await supabase.storage.from(RECORRIDOS_360_BUCKET).upload(path, buffer, {
    contentType: 'image/jpeg',
    // Cada escena tiene su propia ruta (su id) y nunca se reemplaza en el
    // mismo lugar: se puede cachear un año en el celular y en el CDN.
    cacheControl: '31536000',
    upsert: false,
  })
  if (error) {
    throw new Error(`No se pudo subir la imagen: ${error.message}`)
  }
  return supabase.storage.from(RECORRIDOS_360_BUCKET).getPublicUrl(path).data.publicUrl
}

async function assertNombreLibre(nombre: string | undefined, exceptoId?: string) {
  if (!nombre) return
  const otro = await prisma.recorrido360.findFirst({
    where: { nombre: { equals: nombre, mode: 'insensitive' }, ...(exceptoId ? { NOT: { id: exceptoId } } : {}) },
    select: { id: true },
  })
  if (otro) {
    throw new RecorridoNombreDuplicadoError(`Ya existe un recorrido con el nombre "${nombre}"`)
  }
}

async function assertNegocioExiste(negocioId: string | null | undefined) {
  if (!negocioId) return
  const negocio = await prisma.negocioProfile.findUnique({ where: { id: negocioId }, select: { id: true } })
  if (!negocio) {
    throw new RecorridoNotFoundError('No se encontró el negocio indicado')
  }
}

async function findRecorrido(id: string) {
  const recorrido = await prisma.recorrido360.findUnique({ where: { id }, include: { escenas: escenasOrdenadas } })
  if (!recorrido) {
    throw new RecorridoNotFoundError('No se encontró ese recorrido')
  }
  return recorrido
}

export async function createRecorrido(input: RecorridoInput, adminId: string) {
  return withDbGuard(async () => {
    await assertNegocioExiste(input.negocioId)
    await assertNombreLibre(input.nombre)
    return prisma.recorrido360.create({ data: { ...input, creadoPor: adminId }, include: includeAdmin })
  })
}

export async function updateRecorrido(id: string, input: Partial<RecorridoInput>) {
  return withDbGuard(async () => {
    await findRecorrido(id)
    await assertNegocioExiste(input.negocioId)
    await assertNombreLibre(input.nombre, id)
    return prisma.recorrido360.update({ where: { id }, data: input, include: includeAdmin })
  })
}

function rutasDe(escenas: { imagenPath: string; miniaturaPath: string }[]) {
  return escenas.flatMap((e) => [e.imagenPath, e.miniaturaPath])
}

export async function deleteRecorrido(id: string) {
  return withDbGuard(async () => {
    const recorrido = await findRecorrido(id)
    await prisma.recorrido360.delete({ where: { id } })
    // Si falla el borrado en Storage no se revierte nada: el recorrido ya no
    // existe para la app, y unos archivos sueltos no rompen nada.
    const rutas = rutasDe(recorrido.escenas)
    if (rutas.length > 0) {
      await supabase.storage.from(RECORRIDOS_360_BUCKET).remove(rutas)
    }
  })
}

/// Sube la foto de una casilla (1 = "Escenario 1"…). Si la casilla ya tenía
/// foto la reemplaza (conservando su título y sus flechas), así el orden lo
/// decide la casilla y no el orden de subida. La foto se optimiza antes de
/// subirla (ver procesarEscena).
export async function setEscena(recorridoId: string, posicion: number, buffer: Buffer, info: EscenaInfo = {}) {
  return withDbGuard(async () => {
    const recorrido = await findRecorrido(recorridoId)
    const orden = posicion - 1
    const anterior = recorrido.escenas.find((e) => e.orden === orden)

    // Se procesa antes de tocar Storage: una foto que no es 2:1 no deja nada
    // a medio subir.
    const procesada = await procesarEscena(buffer)
    await ensureBucket()

    // Ruta nueva en cada subida (nunca se sobreescribe un archivo): así el
    // caché de un año no sirve una foto vieja después de reemplazarla.
    const archivo = randomUUID()
    const imagenPath = `${recorridoId}/${archivo}.jpg`
    const miniaturaPath = `${recorridoId}/${archivo}_min.jpg`
    const [imagenUrl, miniaturaUrl] = await Promise.all([
      subirArchivo(imagenPath, procesada.imagen),
      subirArchivo(miniaturaPath, procesada.miniatura),
    ])

    const datos = {
      imagenUrl,
      imagenPath,
      miniaturaUrl,
      miniaturaPath,
      ancho: procesada.ancho,
      alto: procesada.alto,
      pesoBytes: procesada.imagen.length,
    }
    const escena = await prisma.recorrido360Escena.upsert({
      where: { recorridoId_orden: { recorridoId, orden } },
      create: { recorridoId, orden, ...info, ...datos },
      update: { ...info, ...datos },
      include: escenasOrdenadas.include,
    })
    if (anterior) {
      await supabase.storage.from(RECORRIDOS_360_BUCKET).remove(rutasDe([anterior]))
    }
    return escena
  })
}

async function findEscena(recorridoId: string, posicion: number) {
  const escena = await prisma.recorrido360Escena.findUnique({
    where: { recorridoId_orden: { recorridoId, orden: posicion - 1 } },
  })
  if (!escena) {
    throw new RecorridoNotFoundError(`El Escenario ${posicion} no existe`)
  }
  return escena
}

/// Título, descripción y hacia dónde mira la cámara al entrar.
export async function updateEscena(recorridoId: string, posicion: number, info: EscenaInfo) {
  return withDbGuard(async () => {
    const escena = await findEscena(recorridoId, posicion)
    return prisma.recorrido360Escena.update({
      where: { id: escena.id },
      data: info,
      include: escenasOrdenadas.include,
    })
  })
}

/// Reemplaza todas las flechas de un escenario de una vez (el panel manda la
/// lista completa al guardar). Cada destino tiene que ser otro escenario de
/// este mismo recorrido que ya tenga foto.
export async function setEnlaces(recorridoId: string, posicion: number, enlaces: EnlaceInput[]) {
  return withDbGuard(async () => {
    const recorrido = await findRecorrido(recorridoId)
    const origen = recorrido.escenas.find((e) => e.orden === posicion - 1)
    if (!origen) {
      throw new RecorridoNotFoundError(`El Escenario ${posicion} no existe`)
    }

    const vistos = new Set<number>()
    const filas = enlaces.map((enlace) => {
      if (enlace.destino === posicion) {
        throw new EnlaceInvalidoError('Una flecha no puede llevar al mismo escenario donde está')
      }
      if (vistos.has(enlace.destino)) {
        throw new EnlaceInvalidoError(`Hay dos flechas hacia el Escenario ${enlace.destino}`)
      }
      vistos.add(enlace.destino)
      const destino = recorrido.escenas.find((e) => e.orden === enlace.destino - 1)
      if (!destino) {
        throw new EnlaceInvalidoError(`El Escenario ${enlace.destino} todavía no tiene foto`)
      }
      return {
        origenId: origen.id,
        destinoId: destino.id,
        yaw: enlace.yaw,
        pitch: enlace.pitch ?? 0,
        etiqueta: enlace.etiqueta ?? '',
      }
    })

    await prisma.$transaction([
      prisma.recorrido360Enlace.deleteMany({ where: { origenId: origen.id } }),
      prisma.recorrido360Enlace.createMany({ data: filas }),
    ])
    return prisma.recorrido360Escena.findUniqueOrThrow({
      where: { id: origen.id },
      include: escenasOrdenadas.include,
    })
  })
}

/// Quita un escenario. Sus flechas y las que llegaban a él se borran solas
/// (ON DELETE CASCADE).
export async function deleteEscena(recorridoId: string, posicion: number) {
  return withDbGuard(async () => {
    const escena = await findEscena(recorridoId, posicion)
    await prisma.recorrido360Escena.delete({ where: { id: escena.id } })
    await supabase.storage.from(RECORRIDOS_360_BUCKET).remove(rutasDe([escena]))
  })
}
