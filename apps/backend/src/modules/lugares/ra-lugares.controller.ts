import { Request, Response } from 'express'
import type { NegocioProfile, PuntoRaGeo } from '@prisma/client'
import { prisma } from '../../config/prisma'
import { withDbGuard, DatabaseNotReadyError } from '../../config/db-guard'
import { RADIO_CERCANO_DEFAULT, RADIO_VISIBLE_DEFAULT } from '../ra-geo/ra-geo.service'

type LugarConPuntos = NegocioProfile & { puntosRaGeo: PuntoRaGeo[]; _count: { arMarcadores: number } }

/// Sin acentos ni mayúsculas, para buscar "electromecánica" o "FIME" igual.
function normalizar(texto: string) {
  return texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim()
}

/// Lugares aprobados con pin, cada uno con sus puntos de RA activos.
function lugaresConPin() {
  return withDbGuard(() =>
    prisma.negocioProfile.findMany({
      where: { estado: 'aprobado', latitud: { not: null }, longitud: { not: null } },
      orderBy: { createdAt: 'asc' },
      include: {
        puntosRaGeo: { where: { activo: true }, orderBy: [{ orden: 'asc' }, { createdAt: 'asc' }] },
        // Para el paso de la geolocalización a los marcadores de imagen del lugar.
        _count: { select: { arMarcadores: { where: { activo: true } } } },
      },
    }),
  )
}

function recortar(texto: string, max: number) {
  return texto.length <= max ? texto : `${texto.slice(0, max - 1).trimEnd()}…`
}

/// Un punto de interés tal como lo consumen la app y Unity.
function toUnityPunto(p: PuntoRaGeo) {
  return {
    id: p.id,
    titulo: p.titulo,
    resumen: p.resumen,
    detalle: p.detalle,
    urlImagen: p.imagenUrl,
    urlAudio: p.audioUrl,
    latitud: p.latitud,
    longitud: p.longitud,
    radioVisible: p.radioVisible,
    radioCercano: p.radioCercano,
  }
}

/// Lugar sin puntos dados de alta: su propio pin hace de punto único, con
/// los radios por defecto (así cualquier lugar con pin ya tiene RA).
function puntoDelPin(n: NegocioProfile) {
  const descripcion = n.descripcion ?? ''
  return {
    id: n.id,
    titulo: n.nombre,
    resumen: recortar(descripcion, 140),
    detalle: descripcion,
    urlImagen: n.portada ?? '',
    urlAudio: '',
    latitud: n.latitud!,
    longitud: n.longitud!,
    radioVisible: RADIO_VISIBLE_DEFAULT,
    radioCercano: RADIO_CERCANO_DEFAULT,
  }
}

/// Contrato con el equipo de Unity para la RA por geolocalización (GET
/// /api/ra/lugares). Mismo estilo que marcadores y recorridos: nada de
/// `null` (JsonUtility no los maneja), lo que falta va como "", y
/// `textoParaMostrar` = nombre + "\n" + descripción. Coordenadas en grados
/// decimales (WGS84). `puntos` nunca viene vacío (ver [puntoDelPin]); cada
/// punto funciona por capas: marcador flotante dentro de `radioVisible` y
/// guía completa (o el paso a los marcadores de imagen del lugar, si
/// `tieneMarcadores`) dentro de `radioCercano` (metros).
/// Si cambia, avisarles y actualizar ModelosLugarRA.cs en apps/ar-module.
function toUnityLugar(n: LugarConPuntos) {
  return {
    id: n.id,
    nombre: n.nombre,
    categoria: n.categoria ?? '',
    textoParaMostrar: n.descripcion ? `${n.nombre}\n${n.descripcion}` : n.nombre,
    direccion: n.direccion ?? '',
    urlPortada: n.portada ?? '',
    latitud: n.latitud!,
    longitud: n.longitud!,
    puntos: n.puntosRaGeo.length > 0 ? n.puntosRaGeo.map(toUnityPunto) : [puntoDelPin(n)],
    /// Si el lugar tiene marcadores de imagen activos (GET /api/marcadores):
    /// al entrar al `radioCercano` de un punto la app ofrece pasar a ellos.
    tieneMarcadores: n._count.arMarcadores > 0,
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
    const lugares = (await lugaresConPin()).filter((n) => !buscar || normalizar(n.nombre).includes(buscar))
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
    const lugar = (await lugaresConPin()).find((n) => n.id === req.params.id)
    if (!lugar) return res.status(404).json({ error: 'No se encontró ese lugar o todavía no tiene ubicación' })
    res.set('Cache-Control', 'no-cache')
    return res.json({ lugar: toUnityLugar(lugar) })
  } catch (err) {
    return fail(res, err)
  }
}
