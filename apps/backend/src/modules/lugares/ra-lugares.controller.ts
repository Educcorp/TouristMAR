import { Request, Response } from 'express'
import type { NegocioProfile } from '@prisma/client'
import { listLugaresPublicos } from './lugares.service'
import { DatabaseNotReadyError } from '../../config/db-guard'

/// Radio (en metros) alrededor del pin dentro del cual se activa la RA por
/// ubicación. Mismo valor por defecto que `Lugar.radioDesbloqueo` en la app.
export const RADIO_RA_METROS = 50

/// Sin acentos ni mayúsculas, para buscar "electromecánica" o "FIME" igual.
function normalizar(texto: string) {
  return texto.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim()
}

/// Contrato con el equipo de Unity para la RA por ubicación (GET
/// /api/ra/lugares). Mismo estilo que marcadores y recorridos: nada de
/// `null` (JsonUtility no los maneja), lo que falta va como "", y
/// `textoParaMostrar` = nombre + "\n" + descripción. Coordenadas en grados
/// decimales (WGS84), las mismas del pin que se ve en el mapa de la app.
/// Si cambia, avisarles.
function toUnityLugar(n: NegocioProfile) {
  return {
    id: n.id,
    nombre: n.nombre,
    categoria: n.categoria ?? '',
    textoParaMostrar: n.descripcion ? `${n.nombre}\n${n.descripcion}` : n.nombre,
    direccion: n.direccion ?? '',
    urlPortada: n.portada ?? '',
    latitud: n.latitud!,
    longitud: n.longitud!,
    radioMetros: RADIO_RA_METROS,
  }
}

function fail(res: Response, err: unknown) {
  if (err instanceof DatabaseNotReadyError) return res.status(503).json({ error: err.message })
  return res.status(500).json({ error: 'Error interno' })
}

/// GET /api/ra/lugares[?buscar=texto] → { "lugares": [ ... ] }
/// Lugares aprobados que tienen pin en el mapa. `buscar` filtra por nombre
/// (sin importar acentos ni mayúsculas), p. ej. ?buscar=electromecanica.
export async function listRaLugares(req: Request, res: Response) {
  try {
    const buscar = typeof req.query.buscar === 'string' ? normalizar(req.query.buscar) : ''
    const lugares = (await listLugaresPublicos()).filter((n) => !buscar || normalizar(n.nombre).includes(buscar))
    res.set('Cache-Control', 'no-cache')
    return res.json({ lugares: lugares.map(toUnityLugar) })
  } catch (err) {
    return fail(res, err)
  }
}

/// GET /api/ra/lugares/:id → { "lugar": { ... } } (404 si no existe, no está
/// aprobado o no tiene pin).
export async function getRaLugar(req: Request, res: Response) {
  try {
    const lugar = (await listLugaresPublicos()).find((n) => n.id === req.params.id)
    if (!lugar) return res.status(404).json({ error: 'No se encontró ese lugar o todavía no tiene ubicación' })
    res.set('Cache-Control', 'no-cache')
    return res.json({ lugar: toUnityLugar(lugar) })
  } catch (err) {
    return fail(res, err)
  }
}
