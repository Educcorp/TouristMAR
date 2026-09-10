import { Response } from 'express'
import { listNegociosPendientes, reviewNegocio, DatabaseNotReadyError } from '../auth/auth.service'
import type { AuthedRequest } from '../auth/auth.middleware'

export async function listPendingNegocios(_req: AuthedRequest, res: Response) {
  try {
    const negocios = await listNegociosPendientes()
    return res.json({
      negocios: negocios.map((n) => ({
        id: n.userId,
        nombre: n.nombre,
        categoria: n.categoria,
        email: n.user.email,
        contacto: n.user.nombres,
        solicitadoEn: n.createdAt,
      })),
    })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

async function decide(req: AuthedRequest, res: Response, decision: 'aprobado' | 'rechazado') {
  try {
    const negocio = await reviewNegocio(req.params.userId, decision, req.userId!)
    return res.json({ negocio })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(404).json({ error: 'No se encontró ese negocio' })
  }
}

export function approveNegocio(req: AuthedRequest, res: Response) {
  return decide(req, res, 'aprobado')
}

export function rejectNegocio(req: AuthedRequest, res: Response) {
  return decide(req, res, 'rechazado')
}
