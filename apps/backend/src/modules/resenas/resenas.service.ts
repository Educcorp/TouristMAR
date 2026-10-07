import { prisma } from '../../config/prisma'
import { withDbGuard } from '../../config/db-guard'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function esUuid(valor: string) {
  return UUID_RE.test(valor)
}

export interface ResumenResenas {
  promedio: number
  total: number
  /// `porEstrellas[i]` = cuántas reseñas tienen `i + 1` estrellas.
  porEstrellas: number[]
}

const redondear = (n: number) => Math.round(n * 10) / 10

/// Promedio y total de varios negocios de una vez (para el mapa, las tarjetas
/// y favoritos). Un negocio sin reseñas no aparece en el resultado.
export async function resumenPorNegocios(negocioIds: string[]) {
  const resumen = new Map<string, { promedio: number; total: number }>()
  if (negocioIds.length === 0) return resumen

  const filas = await withDbGuard(() =>
    prisma.resena.groupBy({
      by: ['negocioId'],
      where: { negocioId: { in: negocioIds } },
      _avg: { estrellas: true },
      _count: { _all: true },
    }),
  )
  for (const f of filas) {
    resumen.set(f.negocioId, { promedio: redondear(f._avg.estrellas ?? 0), total: f._count._all })
  }
  return resumen
}

export async function resumenDeNegocio(negocioId: string): Promise<ResumenResenas> {
  const filas = await withDbGuard(() =>
    prisma.resena.groupBy({ by: ['estrellas'], where: { negocioId }, _count: { _all: true } }),
  )
  const porEstrellas = [0, 0, 0, 0, 0]
  let total = 0
  let suma = 0
  for (const f of filas) {
    porEstrellas[f.estrellas - 1] = f._count._all
    total += f._count._all
    suma += f.estrellas * f._count._all
  }
  return { promedio: total === 0 ? 0 : redondear(suma / total), total, porEstrellas }
}

/// Las más recientes primero. Solo existen para negocios aprobados (así se
/// validan al crearse); si un negocio deja de estar aprobado, su ficha ya no
/// se muestra, así que no se filtra aquí.
export async function listResenasDeNegocio(negocioId: string, limite = 200) {
  return withDbGuard(() =>
    prisma.resena.findMany({
      where: { negocioId },
      orderBy: { createdAt: 'desc' },
      take: limite,
      include: { user: { select: { nombres: true, apellidos: true, avatarUrl: true } } },
    }),
  )
}

export type ResultadoGuardar = 'ok' | 'no_encontrado' | 'propio'

/// Crea o edita la reseña del usuario sobre un lugar (una por lugar).
export async function guardarResena(userId: string, negocioId: string, estrellas: number, comentario: string | null) {
  return withDbGuard(async (): Promise<ResultadoGuardar> => {
    const negocio = await prisma.negocioProfile.findFirst({
      where: { id: negocioId, estado: 'aprobado' },
      select: { userId: true },
    })
    if (!negocio) return 'no_encontrado'
    if (negocio.userId === userId) return 'propio'

    await prisma.resena.upsert({
      where: { userId_negocioId: { userId, negocioId } },
      create: { userId, negocioId, estrellas, comentario },
      update: { estrellas, comentario },
    })
    return 'ok'
  })
}

export async function borrarResenaPropia(userId: string, negocioId: string) {
  return withDbGuard(() => prisma.resena.deleteMany({ where: { userId, negocioId } }))
}

export async function listMisResenas(userId: string) {
  return withDbGuard(() =>
    prisma.resena.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: { negocio: { select: { id: true, nombre: true, categoria: true, portada: true } } },
    }),
  )
}

export type ResultadoResponder = 'ok' | 'no_encontrada' | 'prohibido'

/// Solo el dueño del negocio reseñado responde. `respuesta = null` la quita.
export async function responderResena(userId: string, resenaId: string, respuesta: string | null) {
  return withDbGuard(async (): Promise<ResultadoResponder> => {
    const resena = await prisma.resena.findUnique({
      where: { id: resenaId },
      select: { negocio: { select: { userId: true } } },
    })
    if (!resena) return 'no_encontrada'
    if (resena.negocio.userId !== userId) return 'prohibido'

    await prisma.resena.update({
      where: { id: resenaId },
      data: { respuesta, respuestaEn: respuesta ? new Date() : null },
    })
    return 'ok'
  })
}

export async function listResenasAdmin(limite = 300) {
  return withDbGuard(() =>
    prisma.resena.findMany({
      orderBy: { createdAt: 'desc' },
      take: limite,
      include: {
        user: { select: { nombres: true, apellidos: true, email: true } },
        negocio: { select: { id: true, nombre: true } },
      },
    }),
  )
}

/// `false` si la reseña ya no existía.
export async function borrarResenaAdmin(resenaId: string) {
  return withDbGuard(async () => {
    const { count } = await prisma.resena.deleteMany({ where: { id: resenaId } })
    return count > 0
  })
}
