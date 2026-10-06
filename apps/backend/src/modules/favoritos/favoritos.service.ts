import { prisma } from '../../config/prisma'
import { withDbGuard } from '../../config/db-guard'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function esUuid(valor: string) {
  return UUID_RE.test(valor)
}

/// Los más recientes primero. Un negocio que dejó de estar aprobado (lo
/// rechazaron o lo suspendieron después) ya no se muestra, pero el favorito
/// se conserva por si vuelve a aprobarse.
export async function listFavoritos(userId: string) {
  return withDbGuard(async () => {
    const filas = await prisma.favorito.findMany({
      where: { userId, negocio: { estado: 'aprobado' } },
      orderBy: { createdAt: 'desc' },
      include: { negocio: true },
    })
    return filas.map((f) => f.negocio)
  })
}

/// Devuelve `false` si el lugar no existe o no está aprobado. Es idempotente:
/// marcar dos veces el mismo lugar no falla ni duplica.
export async function addFavorito(userId: string, negocioId: string) {
  return withDbGuard(async () => {
    const negocio = await prisma.negocioProfile.findFirst({
      where: { id: negocioId, estado: 'aprobado' },
      select: { id: true },
    })
    if (!negocio) return false

    await prisma.favorito.upsert({
      where: { userId_negocioId: { userId, negocioId } },
      create: { userId, negocioId },
      update: {},
    })
    return true
  })
}

export async function removeFavorito(userId: string, negocioId: string) {
  return withDbGuard(() => prisma.favorito.deleteMany({ where: { userId, negocioId } }))
}
