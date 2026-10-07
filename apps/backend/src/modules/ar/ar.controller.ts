import { Request, Response } from 'express'
import { z } from 'zod'
import type { ArMarcador } from '@prisma/client'
import {
  listPublicMarcadores,
  listAllMarcadores,
  createMarcador,
  updateMarcador,
  replaceMarcadorImagen,
  deleteMarcador,
  registerEscaneo,
  ArMarcadorNotFoundError,
  ArImagenInvalidaError,
  ArNombreDuplicadoError,
} from './ar.service'
import { DatabaseNotReadyError } from '../../config/db-guard'
import type { AuthedRequest } from '../auth/auth.middleware'

type MarcadorConRelaciones = ArMarcador & {
  negocio: { nombre: string } | null
  _count?: { escaneos: number }
}

/// Contrato acordado con el equipo de Unity — EXACTAMENTE estos tres campos
/// (su script `MarcadorDinamico` los lee con `JsonUtility.FromJson` a
/// `DatosMarcador`, que mapea por nombre de campo). No agregar ni renombrar
/// sin avisarles; si cambia, actualizar también `ModelosMarcador.cs` en
/// apps/ar-module.
///
/// `textoParaMostrar` junta el título y la información que captura el admin
/// en dos líneas: Unity pinta un solo texto sobre el marcador.
function toUnityMarcador(m: ArMarcador) {
  return {
    nombre: m.nombre,
    urlImagen: m.imagenUrl,
    textoParaMostrar: `${m.titulo}\n${m.texto}`,
  }
}

function toAdminMarcador(m: MarcadorConRelaciones) {
  return {
    id: m.id,
    nombre: m.nombre,
    imagenUrl: m.imagenUrl,
    anchoMetros: m.anchoMetros,
    titulo: m.titulo,
    texto: m.texto,
    tipoContenido: m.tipoContenido,
    contenidoUrl: m.contenidoUrl,
    negocioId: m.negocioId,
    negocioNombre: m.negocio?.nombre ?? null,
    activo: m.activo,
    escaneos: m._count?.escaneos ?? 0,
    createdAt: m.createdAt,
    updatedAt: m.updatedAt,
  }
}

function handleError(err: unknown, res: Response) {
  if (err instanceof DatabaseNotReadyError) {
    return res.status(503).json({ error: err.message })
  }
  if (err instanceof ArMarcadorNotFoundError) {
    return res.status(404).json({ error: err.message })
  }
  if (err instanceof ArImagenInvalidaError) {
    return res.status(400).json({ error: err.message })
  }
  if (err instanceof ArNombreDuplicadoError) {
    return res.status(409).json({ error: err.message })
  }
  return res.status(500).json({ error: 'Error interno' })
}

const uuid = z.string().uuid()

// Los campos llegan como texto cuando vienen en un multipart (alta con
// imagen), por eso los números/booleanos se coercionan.
// Identificador para Unity (ver toUnityMarcador): se normaliza a minúsculas
// y solo admite caracteres seguros para usarlo como nombre de imagen y en la
// URL del escaneo, p. ej. "gaviota_01".
const nombreSchema = z
  .string()
  .trim()
  .toLowerCase()
  .min(1)
  .max(60)
  .regex(/^[a-z0-9_-]+$/, 'Usa solo minúsculas, números, guion bajo o guion (ej. gaviota_01)')

const marcadorBaseSchema = z.object({
  nombre: nombreSchema,
  titulo: z.string().trim().min(1).max(80),
  texto: z.string().trim().min(1).max(500),
  anchoMetros: z.coerce.number().positive().max(20).nullable().optional(),
  negocioId: uuid.nullable().optional(),
  tipoContenido: z.enum(['texto', 'imagen', 'modelo_3d', 'video']).optional(),
  contenidoUrl: z.string().url().nullable().optional(),
  activo: z.preprocess((v) => (v === 'true' ? true : v === 'false' ? false : v), z.boolean()).optional(),
})

const createMarcadorSchema = marcadorBaseSchema.extend({
  // En un multipart, "sin negocio" llega como cadena vacía.
  negocioId: z.preprocess((v) => (v === '' ? null : v), uuid.nullable().optional()),
  contenidoUrl: z.preprocess((v) => (v === '' ? null : v), z.string().url().nullable().optional()),
  anchoMetros: z.preprocess((v) => (v === '' ? null : v), z.coerce.number().positive().max(20).nullable().optional()),
})

const updateMarcadorSchema = marcadorBaseSchema.partial()

const escaneoSchema = z.object({
  plataforma: z.enum(['android', 'ios', 'editor']).optional(),
})

// --- Público (lo consume Unity) -------------------------------------------

/// La "lista de tareas" de Unity: se arma en cada petición con lo que hay en
/// la base, así que refleja al instante lo que un admin guarda en el panel
/// (no hace falta generar ningún archivo JSON aparte).
/// GET /api/marcadores[?negocioId=<id del lugar>]. Sin `negocioId` (o vacío)
/// devuelve todos, como siempre; con él, solo los de ese lugar.
export async function listMarcadoresPublic(req: Request, res: Response) {
  const negocioId = typeof req.query.negocioId === 'string' ? req.query.negocioId.trim() : ''
  if (negocioId && !z.string().uuid().safeParse(negocioId).success) {
    return res.status(400).json({ error: 'negocioId inválido' })
  }
  try {
    const marcadores = await listPublicMarcadores(negocioId || undefined)
    // Que ningún proxy/CDN guarde una versión vieja: Unity debe ver siempre
    // los marcadores recién dados de alta.
    res.set('Cache-Control', 'no-cache')
    return res.json({ marcadores: marcadores.map(toUnityMarcador) })
  } catch (err) {
    return handleError(err, res)
  }
}

export async function createEscaneo(req: AuthedRequest, res: Response) {
  const nombre = nombreSchema.safeParse(req.params.nombre)
  const body = escaneoSchema.safeParse(req.body ?? {})
  if (!nombre.success) {
    return res.status(404).json({ error: 'No se encontró ese marcador' })
  }
  if (!body.success) {
    return res.status(400).json({ error: 'Datos inválidos' })
  }

  try {
    await registerEscaneo(nombre.data, req.userId, body.data.plataforma)
    return res.status(204).send()
  } catch (err) {
    return handleError(err, res)
  }
}

// --- Admin (panel web) ----------------------------------------------------

export async function listMarcadoresAdmin(_req: AuthedRequest, res: Response) {
  try {
    const marcadores = await listAllMarcadores()
    return res.json({ marcadores: marcadores.map(toAdminMarcador) })
  } catch (err) {
    return handleError(err, res)
  }
}

export async function createMarcadorAdmin(req: AuthedRequest & { file?: Express.Multer.File }, res: Response) {
  if (!req.file) {
    return res.status(400).json({ error: 'No se recibió la imagen del marcador' })
  }
  const parsed = createMarcadorSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }

  try {
    const marcador = await createMarcador(parsed.data, { buffer: req.file.buffer, mimetype: req.file.mimetype }, req.userId!)
    return res.status(201).json({ marcador: toAdminMarcador(marcador) })
  } catch (err) {
    return handleError(err, res)
  }
}

export async function updateMarcadorAdmin(req: AuthedRequest, res: Response) {
  const id = uuid.safeParse(req.params.id)
  if (!id.success) {
    return res.status(404).json({ error: 'No se encontró ese marcador' })
  }
  const parsed = updateMarcadorSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }

  try {
    const marcador = await updateMarcador(id.data, parsed.data)
    return res.json({ marcador: toAdminMarcador(marcador) })
  } catch (err) {
    return handleError(err, res)
  }
}

export async function replaceImagenAdmin(req: AuthedRequest & { file?: Express.Multer.File }, res: Response) {
  const id = uuid.safeParse(req.params.id)
  if (!id.success) {
    return res.status(404).json({ error: 'No se encontró ese marcador' })
  }
  if (!req.file) {
    return res.status(400).json({ error: 'No se recibió la imagen del marcador' })
  }

  try {
    const marcador = await replaceMarcadorImagen(id.data, { buffer: req.file.buffer, mimetype: req.file.mimetype })
    return res.json({ marcador: toAdminMarcador(marcador) })
  } catch (err) {
    return handleError(err, res)
  }
}

export async function deleteMarcadorAdmin(req: AuthedRequest, res: Response) {
  const id = uuid.safeParse(req.params.id)
  if (!id.success) {
    return res.status(404).json({ error: 'No se encontró ese marcador' })
  }

  try {
    await deleteMarcador(id.data)
    return res.status(204).send()
  } catch (err) {
    return handleError(err, res)
  }
}
