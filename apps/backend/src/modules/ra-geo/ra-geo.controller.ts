import { Response } from 'express'
import { z } from 'zod'
import type { PuntoRaGeo } from '@prisma/client'
import {
  listPuntos,
  crearPunto,
  actualizarPunto,
  borrarPunto,
  PuntoNotFoundError,
  LugarDelPuntoNotFoundError,
  RadiosInvalidosError,
} from './ra-geo.service'
import { DatabaseNotReadyError } from '../../config/db-guard'
import type { AuthedRequest } from '../auth/auth.middleware'

function fail(res: Response, err: unknown) {
  if (err instanceof DatabaseNotReadyError) return res.status(503).json({ error: err.message })
  if (err instanceof PuntoNotFoundError || err instanceof LugarDelPuntoNotFoundError) {
    return res.status(404).json({ error: err.message })
  }
  if (err instanceof RadiosInvalidosError) return res.status(400).json({ error: err.message })
  return res.status(500).json({ error: 'Error interno' })
}

export function toPunto(p: PuntoRaGeo) {
  return {
    id: p.id,
    negocioId: p.negocioId,
    titulo: p.titulo,
    resumen: p.resumen,
    detalle: p.detalle,
    imagenUrl: p.imagenUrl,
    audioUrl: p.audioUrl,
    latitud: p.latitud,
    longitud: p.longitud,
    radioVisible: p.radioVisible,
    radioCercano: p.radioCercano,
    orden: p.orden,
    activo: p.activo,
  }
}

const uuid = z.string().uuid()
const url = z.union([z.literal(''), z.string().trim().url().max(1000)])

// El radio cercano baja hasta 3 m (menos ya es más chico que el error del
// GPS) y el visible llega a 2 km.
const camposSchema = z.object({
  titulo: z.string().trim().min(1).max(120),
  resumen: z.string().trim().max(200),
  detalle: z.string().trim().max(4000),
  imagenUrl: url,
  audioUrl: url,
  latitud: z.number().min(-90).max(90),
  longitud: z.number().min(-180).max(180),
  radioVisible: z.number().min(10).max(2000),
  radioCercano: z.number().min(3).max(500),
  orden: z.number().int().min(0).max(999),
  activo: z.boolean(),
})

const radiosValidos = (p: { radioVisible?: number; radioCercano?: number }) =>
  p.radioVisible == null || p.radioCercano == null || p.radioCercano < p.radioVisible
const mensajeRadios = { message: 'El radio cercano tiene que ser menor que el radio visible', path: ['radioCercano'] }

const crearSchema = camposSchema
  .partial({ resumen: true, detalle: true, imagenUrl: true, audioUrl: true, radioVisible: true, radioCercano: true, orden: true, activo: true })
  .refine(radiosValidos, mensajeRadios)
const editarSchema = camposSchema.partial()

/// GET /api/admin/ra-geo/lugares/:negocioId/puntos
export async function listPuntosAdmin(req: AuthedRequest, res: Response) {
  if (!uuid.safeParse(req.params.negocioId).success) return res.status(404).json({ error: 'No se encontró el lugar' })
  try {
    const puntos = await listPuntos(req.params.negocioId)
    return res.json({ puntos: puntos.map(toPunto) })
  } catch (err) {
    return fail(res, err)
  }
}

/// POST /api/admin/ra-geo/lugares/:negocioId/puntos
export async function crearPuntoAdmin(req: AuthedRequest, res: Response) {
  if (!uuid.safeParse(req.params.negocioId).success) return res.status(404).json({ error: 'No se encontró el lugar' })
  const parsed = crearSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }
  try {
    const punto = await crearPunto(req.params.negocioId, parsed.data)
    return res.status(201).json({ punto: toPunto(punto) })
  } catch (err) {
    return fail(res, err)
  }
}

/// PATCH /api/admin/ra-geo/puntos/:id
export async function editarPuntoAdmin(req: AuthedRequest, res: Response) {
  if (!uuid.safeParse(req.params.id).success) return res.status(404).json({ error: 'No se encontró ese punto' })
  const parsed = editarSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }
  try {
    const punto = await actualizarPunto(req.params.id, parsed.data)
    return res.json({ punto: toPunto(punto) })
  } catch (err) {
    return fail(res, err)
  }
}

/// DELETE /api/admin/ra-geo/puntos/:id
export async function borrarPuntoAdmin(req: AuthedRequest, res: Response) {
  if (!uuid.safeParse(req.params.id).success) return res.status(404).json({ error: 'No se encontró ese punto' })
  try {
    await borrarPunto(req.params.id)
    return res.status(204).send()
  } catch (err) {
    return fail(res, err)
  }
}
