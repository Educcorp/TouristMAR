import { prisma } from '../../config/prisma'
import { withDbGuard } from '../../config/db-guard'

export class PuntoNotFoundError extends Error {}
export class LugarDelPuntoNotFoundError extends Error {}
export class RadiosInvalidosError extends Error {}

/// Radios por defecto de las capas (metros): a 100 m aparece el marcador
/// flotante y a 10 m se abre la guía completa. Mismos valores que en la app.
export const RADIO_VISIBLE_DEFAULT = 100
export const RADIO_CERCANO_DEFAULT = 10

export interface PuntoInput {
  titulo: string
  resumen?: string
  detalle?: string
  imagenUrl?: string
  audioUrl?: string
  latitud: number
  longitud: number
  radioVisible?: number
  radioCercano?: number
  orden?: number
  activo?: boolean
}

export async function listPuntos(negocioId: string) {
  return withDbGuard(() =>
    prisma.puntoRaGeo.findMany({ where: { negocioId }, orderBy: [{ orden: 'asc' }, { createdAt: 'asc' }] }),
  )
}

export async function crearPunto(negocioId: string, input: PuntoInput) {
  return withDbGuard(async () => {
    const lugar = await prisma.negocioProfile.findUnique({ where: { id: negocioId }, select: { id: true } })
    if (!lugar) throw new LugarDelPuntoNotFoundError('No se encontró el lugar')
    // Si no mandan orden, va al final.
    const orden = input.orden ?? (await prisma.puntoRaGeo.count({ where: { negocioId } }))
    return prisma.puntoRaGeo.create({ data: { ...input, orden, negocioId } })
  })
}

/// Los radios se validan contra lo ya guardado cuando solo llega uno.
export async function actualizarPunto(id: string, input: Partial<PuntoInput>) {
  return withDbGuard(async () => {
    const actual = await prisma.puntoRaGeo.findUnique({ where: { id } })
    if (!actual) throw new PuntoNotFoundError('No se encontró ese punto')
    const visible = input.radioVisible ?? actual.radioVisible
    const cercano = input.radioCercano ?? actual.radioCercano
    if (cercano >= visible) throw new RadiosInvalidosError('El radio cercano tiene que ser menor que el radio visible')
    return prisma.puntoRaGeo.update({ where: { id }, data: input })
  })
}

export async function borrarPunto(id: string) {
  return withDbGuard(async () => {
    const { count } = await prisma.puntoRaGeo.deleteMany({ where: { id } })
    if (count === 0) throw new PuntoNotFoundError('No se encontró ese punto')
  })
}
