import { Request, Response } from 'express'
import { listLugaresPublicos } from './lugares.service'
import { DatabaseNotReadyError } from '../../config/db-guard'

export async function listPublicos(_req: Request, res: Response) {
  try {
    const negocios = await listLugaresPublicos()
    return res.json({
      lugares: negocios.map((n) => ({
        id: n.id,
        nombre: n.nombre,
        categoria: n.categoria,
        descripcion: n.descripcion,
        direccion: n.direccion,
        telefono: n.telefono,
        sitioWeb: n.sitioWeb,
        horario: n.horario,
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
