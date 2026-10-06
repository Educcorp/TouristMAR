import { Response } from 'express'
import { addFavorito, esUuid, listFavoritos, removeFavorito } from './favoritos.service'
import { DatabaseNotReadyError } from '../../config/db-guard'
import type { AuthedRequest } from '../auth/auth.middleware'

function fail(res: Response, err: unknown) {
  if (err instanceof DatabaseNotReadyError) {
    return res.status(503).json({ error: err.message })
  }
  return res.status(500).json({ error: 'Error interno' })
}

/// Mismo shape que `GET /api/lugares` (y que `NegocioInfo`), para reusar
/// `NegocioInfo.fromJson` en el frontend.
export async function listMine(req: AuthedRequest, res: Response) {
  try {
    const negocios = await listFavoritos(req.userId!)
    return res.json({
      favoritos: negocios.map((n) => ({
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
        estado: n.estado,
        createdAt: n.createdAt,
      })),
    })
  } catch (err) {
    return fail(res, err)
  }
}

export async function add(req: AuthedRequest, res: Response) {
  const { negocioId } = req.params
  if (!esUuid(negocioId)) return res.status(400).json({ error: 'Lugar inválido' })
  try {
    const ok = await addFavorito(req.userId!, negocioId)
    if (!ok) return res.status(404).json({ error: 'Lugar no encontrado' })
    return res.status(204).send()
  } catch (err) {
    return fail(res, err)
  }
}

export async function remove(req: AuthedRequest, res: Response) {
  const { negocioId } = req.params
  if (!esUuid(negocioId)) return res.status(400).json({ error: 'Lugar inválido' })
  try {
    await removeFavorito(req.userId!, negocioId)
    return res.status(204).send()
  } catch (err) {
    return fail(res, err)
  }
}
