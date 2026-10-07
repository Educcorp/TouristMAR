import { Response } from 'express'
import { z } from 'zod'
import type { SolicitudRecorrido360 } from '@prisma/client'
import {
  estadoRecorridoNegocio,
  solicitarRecorrido,
  listSolicitudes,
  atenderSolicitud,
  SolicitudInvalidaError,
  SolicitudConflictoError,
  SolicitudNotFoundError,
} from './solicitudes.service'
import { NegocioNotFoundError } from '../auth/auth.service'
import { DatabaseNotReadyError } from '../../config/db-guard'
import type { AuthedRequest } from '../auth/auth.middleware'

type SolicitudConNegocio = SolicitudRecorrido360 & {
  negocio: {
    id: string
    nombre: string
    categoria: string | null
    direccion: string | null
    telefono: string | null
    latitud: number | null
    longitud: number | null
    user: { nombres: string; apellidos: string | null; email: string }
  }
}

function handleError(err: unknown, res: Response) {
  if (err instanceof DatabaseNotReadyError) return res.status(503).json({ error: err.message })
  if (err instanceof NegocioNotFoundError || err instanceof SolicitudNotFoundError) {
    return res.status(404).json({ error: err.message })
  }
  if (err instanceof SolicitudInvalidaError) return res.status(400).json({ error: err.message })
  if (err instanceof SolicitudConflictoError) return res.status(409).json({ error: err.message })
  return res.status(500).json({ error: 'Error interno' })
}

function toSolicitud(s: SolicitudRecorrido360) {
  return {
    id: s.id,
    negocioId: s.negocioId,
    estado: s.estado,
    mensaje: s.mensaje,
    nota: s.nota,
    createdAt: s.createdAt,
    atendidaEn: s.atendidaEn,
  }
}

function toAdminSolicitud(s: SolicitudConNegocio) {
  const { user, ...negocio } = s.negocio
  return {
    ...toSolicitud(s),
    negocio: {
      ...negocio,
      contacto: [user.nombres, user.apellidos].filter(Boolean).join(' '),
      email: user.email,
    },
  }
}

const uuid = z.string().uuid()

const solicitarSchema = z.object({ mensaje: z.string().trim().max(500).optional() })

const atenderSchema = z.object({
  estado: z.enum(['completada', 'rechazada']),
  nota: z.string().trim().max(500).optional(),
})

/// GET /api/auth/profile/negocios/:negocioId/recorrido-360
export async function estadoRecorrido(req: AuthedRequest, res: Response) {
  if (!uuid.safeParse(req.params.negocioId).success) {
    return res.status(404).json({ error: 'No se encontró ese negocio' })
  }
  try {
    const { tieneRecorrido, solicitud } = await estadoRecorridoNegocio(req.params.negocioId, req.userId!)
    return res.json({ tieneRecorrido, solicitud: solicitud ? toSolicitud(solicitud) : null })
  } catch (err) {
    return handleError(err, res)
  }
}

/// POST /api/auth/profile/negocios/:negocioId/recorrido-360/solicitud
export async function crearSolicitud(req: AuthedRequest, res: Response) {
  if (!uuid.safeParse(req.params.negocioId).success) {
    return res.status(404).json({ error: 'No se encontró ese negocio' })
  }
  const parsed = solicitarSchema.safeParse(req.body ?? {})
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }
  try {
    const solicitud = await solicitarRecorrido(req.params.negocioId, req.userId!, parsed.data.mensaje ?? '')
    return res.status(201).json({ solicitud: toSolicitud(solicitud) })
  } catch (err) {
    return handleError(err, res)
  }
}

/// GET /api/admin/recorridos/solicitudes?estado=pendiente
export async function listSolicitudesAdmin(req: AuthedRequest, res: Response) {
  const estado = z.enum(['pendiente', 'completada', 'rechazada']).optional().safeParse(req.query.estado)
  if (!estado.success) return res.status(400).json({ error: 'Estado inválido' })
  try {
    const solicitudes = await listSolicitudes(estado.data)
    return res.json({ solicitudes: (solicitudes as SolicitudConNegocio[]).map(toAdminSolicitud) })
  } catch (err) {
    return handleError(err, res)
  }
}

/// PATCH /api/admin/recorridos/solicitudes/:id  { estado, nota? }
export async function atenderSolicitudAdmin(req: AuthedRequest, res: Response) {
  if (!uuid.safeParse(req.params.id).success) {
    return res.status(404).json({ error: 'No se encontró esa solicitud' })
  }
  const parsed = atenderSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }
  try {
    const solicitud = await atenderSolicitud(req.params.id, parsed.data.estado, parsed.data.nota ?? '', req.userId!)
    return res.json({ solicitud: toAdminSolicitud(solicitud as SolicitudConNegocio) })
  } catch (err) {
    return handleError(err, res)
  }
}
