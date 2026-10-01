import { prisma } from '../../config/prisma'
import { withDbGuard } from '../../config/db-guard'

/// El mapa público solo puede pintar un pin si el negocio está aprobado y ya
/// tiene coordenadas — la mayoría de los negocios existentes todavía no
/// tienen `latitud`/`longitud` (se completan a mano o desde el panel del
/// dueño más adelante), así que quedan fuera de esta lista hasta que las
/// tengan.
export async function listLugaresPublicos() {
  return withDbGuard(() =>
    prisma.negocioProfile.findMany({
      where: {
        estado: 'aprobado',
        latitud: { not: null },
        longitud: { not: null },
      },
      orderBy: { createdAt: 'asc' },
    }),
  )
}
