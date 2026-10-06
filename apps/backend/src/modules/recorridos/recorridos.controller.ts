import { Request, Response } from 'express'
import { z } from 'zod'
import type { Recorrido360, Recorrido360Escena, Recorrido360Enlace } from '@prisma/client'
import {
  listPublicRecorridos,
  getPublicRecorrido,
  listAllRecorridos,
  createRecorrido,
  updateRecorrido,
  deleteRecorrido,
  setEscena,
  updateEscena,
  setEnlaces,
  deleteEscena,
  MAX_ESCENARIOS,
  RecorridoNotFoundError,
  RecorridoNombreDuplicadoError,
  EnlaceInvalidoError,
} from './recorridos.service'
import { EscenaImagenInvalidaError } from './escena-imagen'
import { DatabaseNotReadyError } from '../../config/db-guard'
import type { AuthedRequest } from '../auth/auth.middleware'

type EnlaceConDestino = Recorrido360Enlace & { destino: { orden: number } }
type EscenaConEnlaces = Recorrido360Escena & { enlaces: EnlaceConDestino[] }
type RecorridoConEscenas = Recorrido360 & { escenas: EscenaConEnlaces[] }
type RecorridoAdmin = RecorridoConEscenas & { negocio: { nombre: string } | null }

const tituloEscena = (e: Recorrido360Escena) => e.titulo || `Escenario ${e.orden + 1}`

/// Contrato con el equipo de Unity (GET /api/recorridos). Mismo estilo que
/// el de marcadores: `textoParaMostrar` = título + "\n" + información, y
/// nada de `null` (JsonUtility no los maneja): lo que falta va como "".
/// `escenas` viene en orden de casilla y el visor arranca en `escenaInicial`
/// (el Escenario 1, o el primero que tenga foto). Cada flecha apunta a otra
/// escena por su `id`. Ángulos en grados.
/// Si cambia, avisarles y actualizar ModelosRecorrido.cs en apps/ar-module.
function toUnityRecorrido(r: RecorridoConEscenas) {
  const titulos = new Map(r.escenas.map((e) => [e.id, tituloEscena(e)]))
  return {
    nombre: r.nombre,
    textoParaMostrar: `${r.titulo}\n${r.texto}`,
    negocioId: r.negocioId ?? '',
    /// Miniatura de la primera escena, para listar el recorrido en un menú
    /// sin descargar ninguna foto 360° completa.
    urlPortada: r.escenas[0]?.miniaturaUrl ?? '',
    /// Pin del recorrido. JsonUtility no maneja null: sin ubicación va
    /// `tieneUbicacion: false` y 0, 0.
    tieneUbicacion: r.latitud != null && r.longitud != null,
    latitud: r.latitud ?? 0,
    longitud: r.longitud ?? 0,
    escenaInicial: r.escenas[0]?.id ?? '',
    escenas: r.escenas.map((e) => ({
      id: e.id,
      titulo: tituloEscena(e),
      descripcion: e.descripcion,
      urlImagen: e.imagenUrl,
      urlMiniatura: e.miniaturaUrl,
      yawInicial: e.yawInicial,
      enlaces: e.enlaces.map((l) => ({
        destino: l.destinoId,
        yaw: l.yaw,
        pitch: l.pitch,
        etiqueta: l.etiqueta || titulos.get(l.destinoId) || '',
      })),
    })),
  }
}

function toAdminEscena(e: EscenaConEnlaces) {
  return {
    id: e.id,
    posicion: e.orden + 1,
    titulo: e.titulo,
    descripcion: e.descripcion,
    yawInicial: e.yawInicial,
    imagenUrl: e.imagenUrl,
    miniaturaUrl: e.miniaturaUrl,
    ancho: e.ancho,
    alto: e.alto,
    pesoBytes: e.pesoBytes,
    /// Flechas hacia otros escenarios; `destino` es la casilla (1–32).
    enlaces: e.enlaces.map((l) => ({
      destino: l.destino.orden + 1,
      yaw: l.yaw,
      pitch: l.pitch,
      etiqueta: l.etiqueta,
    })),
    createdAt: e.createdAt,
  }
}

function toAdminRecorrido(r: RecorridoAdmin) {
  return {
    id: r.id,
    nombre: r.nombre,
    titulo: r.titulo,
    texto: r.texto,
    negocioId: r.negocioId,
    negocioNombre: r.negocio?.nombre ?? null,
    latitud: r.latitud,
    longitud: r.longitud,
    activo: r.activo,
    escenas: r.escenas.map(toAdminEscena),
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  }
}

function handleError(err: unknown, res: Response) {
  if (err instanceof DatabaseNotReadyError) {
    return res.status(503).json({ error: err.message })
  }
  if (err instanceof RecorridoNotFoundError) {
    return res.status(404).json({ error: err.message })
  }
  if (err instanceof EscenaImagenInvalidaError || err instanceof EnlaceInvalidoError) {
    return res.status(400).json({ error: err.message })
  }
  if (err instanceof RecorridoNombreDuplicadoError) {
    return res.status(409).json({ error: err.message })
  }
  return res.status(500).json({ error: 'Error interno' })
}

const uuid = z.string().uuid()

// Mismo formato que el nombre de los marcadores: seguro para usarlo en URLs
// y como clave en Unity, p. ej. "cerro_vigia_360".
const nombreSchema = z
  .string()
  .trim()
  .toLowerCase()
  .min(1)
  .max(60)
  .regex(/^[a-z0-9_-]+$/, 'Usa solo minúsculas, números, guion bajo o guion (ej. cerro_vigia_360)')

const recorridoBaseSchema = z.object({
  nombre: nombreSchema,
  titulo: z.string().trim().min(1).max(80),
  texto: z.string().trim().min(1).max(500),
  negocioId: uuid.nullable().optional(),
  activo: z.boolean().optional(),
  // Pin en el mapa: los dos juntos (o los dos null para quitarlo).
  latitud: z.number().min(-90).max(90).nullable().optional(),
  longitud: z.number().min(-180).max(180).nullable().optional(),
})

const coordenadasJuntas = (d: { latitud?: number | null; longitud?: number | null }) =>
  (d.latitud === undefined) === (d.longitud === undefined) && (d.latitud === null) === (d.longitud === null)

const recorridoSchema = recorridoBaseSchema.refine(coordenadasJuntas, {
  message: 'latitud y longitud van juntas',
  path: ['latitud'],
})
const recorridoParcialSchema = recorridoBaseSchema.partial().refine(coordenadasJuntas, {
  message: 'latitud y longitud van juntas',
  path: ['latitud'],
})

/// Casilla del escenario en la URL: 1 = "Escenario 1" (el de entrada)… 32.
const posicionSchema = z.coerce.number().int().min(1).max(MAX_ESCENARIOS)

/// Grados: yaw -180…180 (0 = centro de la foto), pitch -90…90 (0 = horizonte).
const yawSchema = z.number().min(-180).max(180)

const escenaInfoSchema = z.object({
  titulo: z.string().trim().max(60).optional(),
  descripcion: z.string().trim().max(300).optional(),
  yawInicial: yawSchema.optional(),
})

const enlacesSchema = z.object({
  enlaces: z
    .array(
      z.object({
        destino: posicionSchema,
        yaw: yawSchema,
        pitch: z.number().min(-90).max(90).optional(),
        etiqueta: z.string().trim().max(60).optional(),
      }),
    )
    .max(MAX_ESCENARIOS - 1),
})

const posicionInvalida = `El escenario debe ser del 1 al ${MAX_ESCENARIOS}`

// --- Público (lo consume Unity) -------------------------------------------

/// Se arma en cada petición con lo que hay en la base (no hay archivo JSON
/// generado). Solo lleva URLs: Unity descarga cada foto cuando la necesita.
export async function listRecorridosPublic(req: Request, res: Response) {
  const negocioId = req.query.negocioId === undefined ? undefined : uuid.safeParse(req.query.negocioId)
  if (negocioId && !negocioId.success) {
    return res.status(400).json({ error: 'negocioId inválido' })
  }

  try {
    const recorridos = await listPublicRecorridos(negocioId?.data)
    res.set('Cache-Control', 'no-cache')
    return res.json({ recorridos: recorridos.map(toUnityRecorrido) })
  } catch (err) {
    return handleError(err, res)
  }
}

export async function getRecorridoPublic(req: Request, res: Response) {
  const nombre = nombreSchema.safeParse(req.params.nombre)
  if (!nombre.success) {
    return res.status(404).json({ error: 'No se encontró ese recorrido' })
  }

  try {
    const recorrido = await getPublicRecorrido(nombre.data)
    res.set('Cache-Control', 'no-cache')
    return res.json({ recorrido: toUnityRecorrido(recorrido) })
  } catch (err) {
    return handleError(err, res)
  }
}

// --- Admin (panel web) ----------------------------------------------------

export async function listRecorridosAdmin(_req: AuthedRequest, res: Response) {
  try {
    const recorridos = await listAllRecorridos()
    return res.json({ recorridos: recorridos.map(toAdminRecorrido) })
  } catch (err) {
    return handleError(err, res)
  }
}

export async function createRecorridoAdmin(req: AuthedRequest, res: Response) {
  const parsed = recorridoSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }

  try {
    const recorrido = await createRecorrido(parsed.data, req.userId!)
    return res.status(201).json({ recorrido: toAdminRecorrido(recorrido) })
  } catch (err) {
    return handleError(err, res)
  }
}

export async function updateRecorridoAdmin(req: AuthedRequest, res: Response) {
  const id = uuid.safeParse(req.params.id)
  if (!id.success) {
    return res.status(404).json({ error: 'No se encontró ese recorrido' })
  }
  const parsed = recorridoParcialSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }

  try {
    const recorrido = await updateRecorrido(id.data, parsed.data)
    return res.json({ recorrido: toAdminRecorrido(recorrido) })
  } catch (err) {
    return handleError(err, res)
  }
}

export async function deleteRecorridoAdmin(req: AuthedRequest, res: Response) {
  const id = uuid.safeParse(req.params.id)
  if (!id.success) {
    return res.status(404).json({ error: 'No se encontró ese recorrido' })
  }

  try {
    await deleteRecorrido(id.data)
    return res.status(204).send()
  } catch (err) {
    return handleError(err, res)
  }
}

export async function setEscenaAdmin(req: AuthedRequest & { file?: Express.Multer.File }, res: Response) {
  const id = uuid.safeParse(req.params.id)
  if (!id.success) {
    return res.status(404).json({ error: 'No se encontró ese recorrido' })
  }
  const posicion = posicionSchema.safeParse(req.params.posicion)
  if (!posicion.success) {
    return res.status(400).json({ error: posicionInvalida })
  }
  if (!req.file) {
    return res.status(400).json({ error: 'No se recibió la foto' })
  }
  // Opcional: título/descripción como campos de texto del mismo multipart.
  const info = escenaInfoSchema.omit({ yawInicial: true }).safeParse(req.body ?? {})
  if (!info.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: info.error.flatten().fieldErrors })
  }

  try {
    const escena = await setEscena(id.data, posicion.data, req.file.buffer, info.data)
    return res.json({ escena: toAdminEscena(escena) })
  } catch (err) {
    return handleError(err, res)
  }
}

export async function updateEscenaAdmin(req: AuthedRequest, res: Response) {
  const id = uuid.safeParse(req.params.id)
  const posicion = posicionSchema.safeParse(req.params.posicion)
  if (!id.success || !posicion.success) {
    return res.status(404).json({ error: 'Ese escenario no existe' })
  }
  const parsed = escenaInfoSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }

  try {
    const escena = await updateEscena(id.data, posicion.data, parsed.data)
    return res.json({ escena: toAdminEscena(escena) })
  } catch (err) {
    return handleError(err, res)
  }
}

export async function setEnlacesAdmin(req: AuthedRequest, res: Response) {
  const id = uuid.safeParse(req.params.id)
  const posicion = posicionSchema.safeParse(req.params.posicion)
  if (!id.success || !posicion.success) {
    return res.status(404).json({ error: 'Ese escenario no existe' })
  }
  const parsed = enlacesSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }

  try {
    const escena = await setEnlaces(id.data, posicion.data, parsed.data.enlaces)
    return res.json({ escena: toAdminEscena(escena) })
  } catch (err) {
    return handleError(err, res)
  }
}

export async function deleteEscenaAdmin(req: AuthedRequest, res: Response) {
  const id = uuid.safeParse(req.params.id)
  const posicion = posicionSchema.safeParse(req.params.posicion)
  if (!id.success || !posicion.success) {
    return res.status(404).json({ error: 'Ese escenario no existe' })
  }

  try {
    await deleteEscena(id.data, posicion.data)
    return res.status(204).send()
  } catch (err) {
    return handleError(err, res)
  }
}
