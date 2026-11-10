import { Request, Response } from 'express'
import { listLugaresPublicos, registrarVisita } from './lugares.service'
import { esUuid } from '../resenas/resenas.service'
import type { AuthedRequest } from '../auth/auth.middleware'
import { resumenPorNegocios } from '../resenas/resenas.service'
import { DatabaseNotReadyError } from '../../config/db-guard'

export async function listPublicos(_req: Request, res: Response) {
  try {
    const negocios = await listLugaresPublicos()
    const resenas = await resumenPorNegocios(negocios.map((n) => n.id))
    return res.json({
      lugares: negocios.map((n) => ({
        rating: resenas.get(n.id)?.promedio ?? 0,
        totalResenas: resenas.get(n.id)?.total ?? 0,
        id: n.id,
        nombre: n.nombre,
        categoria: n.categoria,
        descripcion: n.descripcion,
        direccion: n.direccion,
        telefono: n.telefono,
        sitioWeb: n.sitioWeb,
        horario: n.horario,
        costoPorPersona: n.costoPorPersona,
        menu: n.menu,
        portada: n.portada,
        galeria: n.galeria,
        archivo360: n.archivo360,
        arMarcador: n.arMarcador,
        arGeo: n.arGeo,
        latitud: n.latitud,
        longitud: n.longitud,
        // El shape coincide con `NegocioInfo` (mismo modelo que usa
        // /auth/me) para poder reusar `NegocioInfo.fromJson` en el
        // frontend — esta lista ya viene filtrada a `estado: 'aprobado'`.
        estado: n.estado,
        createdAt: n.createdAt,
      })),
    })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

/// POST /api/lugares/:id/visita — la ficha del lugar lo llama al abrirse.
export async function visita(req: AuthedRequest, res: Response) {
  if (!esUuid(req.params.id)) return res.status(404).json({ error: 'No se encontró ese lugar' })
  try {
    const ok = await registrarVisita(req.params.id, req.userId)
    return ok ? res.status(204).send() : res.status(404).json({ error: 'No se encontró ese lugar' })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}
