import { Request, Response } from 'express'
import { z } from 'zod'
import type { Recorrido360, Recorrido360Escena } from '@prisma/client'
import {
  listPublicRecorridos,
  getPublicRecorrido,
  listAllRecorridos,
  createRecorrido,
  updateRecorrido,
  deleteRecorrido,
  setEscena,
  deleteEscena,
  FOTOS_POR_RECORRIDO,
  RecorridoNotFoundError,
  RecorridoNombreDuplicadoError,
} from './recorridos.service'
import { EscenaImagenInvalidaError } from './escena-imagen'
import { DatabaseNotReadyError } from '../../config/db-guard'
import type { AuthedRequest } from '../auth/auth.middleware'

type RecorridoConEscenas = Recorrido360 & { escenas: Recorrido360Escena[] }
type RecorridoAdmin = RecorridoConEscenas & { negocio: { nombre: string } | null }

/// Contrato con el equipo de Unity (GET /api/recorridos). Mismo estilo que
/// el de marcadores: `textoParaMostrar` = título + "\n" + información, y
/// nada de `null` (JsonUtility no los maneja): lo que falta va como "".
/// `escenas` siempre trae las 3 fotos en orden ("Foto 1", "Foto 2",
/// "Foto 3"): el endpoint público solo lista recorridos completos.
/// Si cambia, avisarles y actualizar ModelosRecorrido.cs en apps/ar-module.
function toUnityRecorrido(r: RecorridoConEscenas) {
  return {
    nombre: r.nombre,
    textoParaMostrar: `${r.titulo}\n${r.texto}`,
    negocioId: r.negocioId ?? '',
    /// Miniatura de la primera escena, para listar el recorrido en un menú
    /// sin descargar ninguna foto 360° completa.
    urlPortada: r.escenas[0]?.miniaturaUrl ?? '',
    escenas: r.escenas.map((e) => ({
      titulo: `Foto ${e.orden + 1}`,
      urlImagen: e.imagenUrl,
    })),
  }
}

function toAdminEscena(e: Recorrido360Escena) {
  return {
    id: e.id,
    posicion: e.orden + 1,
    imagenUrl: e.imagenUrl,
    miniaturaUrl: e.miniaturaUrl,
    ancho: e.ancho,
    alto: e.alto,
    pesoBytes: e.pesoBytes,
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
  if (err instanceof EscenaImagenInvalidaError) {
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

const recorridoSchema = z.object({
  nombre: nombreSchema,
  titulo: z.string().trim().min(1).max(80),
  texto: z.string().trim().min(1).max(500),
  negocioId: uuid.nullable().optional(),
  activo: z.boolean().optional(),
})

/// Casilla de la foto en la URL: 1 = "Foto 1", 2 = "Foto 2", 3 = "Foto 3".
const posicionSchema = z.coerce.number().int().min(1).max(FOTOS_POR_RECORRIDO)

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
  const parsed = recorridoSchema.partial().safeParse(req.body)
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
    return res.status(400).json({ error: `La foto debe ser la 1, 2 o 3` })
  }
  if (!req.file) {
    return res.status(400).json({ error: 'No se recibió la foto' })
  }

  try {
    const escena = await setEscena(id.data, posicion.data, req.file.buffer)
    return res.json({ escena: toAdminEscena(escena) })
  } catch (err) {
    return handleError(err, res)
  }
}

export async function deleteEscenaAdmin(req: AuthedRequest, res: Response) {
  const id = uuid.safeParse(req.params.id)
  const posicion = posicionSchema.safeParse(req.params.posicion)
  if (!id.success || !posicion.success) {
    return res.status(404).json({ error: 'Esa foto no existe' })
  }

  try {
    await deleteEscena(id.data, posicion.data)
    return res.status(204).send()
  } catch (err) {
    return handleError(err, res)
  }
}
