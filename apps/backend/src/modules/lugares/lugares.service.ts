import { prisma } from '../../config/prisma'
import { withDbGuard } from '../../config/db-guard'
import { deleteRecorrido } from '../recorridos/recorridos.service'
import { deleteMarcador } from '../ar/ar.service'

/// El mapa público solo puede pintar un pin si el negocio está aprobado y ya
/// tiene coordenadas — la mayoría de los negocios existentes todavía no
/// tienen `latitud`/`longitud` (se completan a mano o desde el panel del
/// dueño más adelante), así que quedan fuera de esta lista hasta que las
/// tengan.
export class LugarNotFoundError extends Error {}
export class SinSuperAdminError extends Error {}

export interface LugarAdminInput {
  nombre: string
  categoria?: string | null
  descripcion?: string | null
  direccion?: string | null
  // Contacto: lo manda la empresa en su solicitud y el admin lo puede
  // corregir desde el detalle de la solicitud.
  telefono?: string | null
  sitioWeb?: string | null
  horario?: string | null
  latitud?: number | null
  longitud?: number | null
}

/// Un lugar que da de alta un admin (una facultad, un mirador, una playa):
/// no es de ningún dueño, así que se guarda a nombre del super admin (la
/// única cuenta que no se puede borrar; si fuera de un admin normal, al
/// borrarlo se borraría el lugar en cascada). Ya nace aprobado.
export async function crearLugarAdmin(input: LugarAdminInput) {
  return withDbGuard(async () => {
    const superAdmin = await prisma.user.findFirst({
      where: { rol: 'super_admin' },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    })
    if (!superAdmin) {
      throw new SinSuperAdminError('No hay una cuenta de super administrador para registrar el lugar')
    }
    return prisma.negocioProfile.create({
      data: { ...input, userId: superAdmin.id, estado: 'aprobado', revisadoPor: superAdmin.id, revisadoEn: new Date() },
      include: { user: { select: { email: true, nombres: true } } },
    })
  })
}

/// El admin corrige los datos de cualquier lugar (dirección, pin…).
export async function actualizarLugarAdmin(negocioId: string, input: Partial<LugarAdminInput>) {
  return withDbGuard(async () => {
    const negocio = await prisma.negocioProfile.findUnique({ where: { id: negocioId }, select: { id: true } })
    if (!negocio) {
      throw new LugarNotFoundError('No se encontró ese lugar')
    }
    return prisma.negocioProfile.update({
      where: { id: negocioId },
      data: input,
      include: { user: { select: { email: true, nombres: true } } },
    })
  })
}

/// Fija (o quita, con null) el pin de un negocio en el mapa. Lo usa el admin
/// para cualquier negocio; el dueño lo hace desde PATCH /auth/profile/negocios/:id.
export async function setUbicacionNegocio(negocioId: string, ubicacion: { latitud: number; longitud: number } | null) {
  return withDbGuard(async () => {
    const negocio = await prisma.negocioProfile.findUnique({ where: { id: negocioId }, select: { id: true } })
    if (!negocio) {
      throw new LugarNotFoundError('No se encontró ese negocio')
    }
    return prisma.negocioProfile.update({
      where: { id: negocioId },
      data: { latitud: ubicacion?.latitud ?? null, longitud: ubicacion?.longitud ?? null },
    })
  })
}

/// Borra un lugar desde "Mapa y RA". Primero sus recorridos y marcadores con
/// sus propias funciones (así también se borran sus fotos de Storage; la
/// cascada de la base solo borraría las filas) y luego el lugar.
export async function eliminarLugarAdmin(negocioId: string) {
  const lugar = await withDbGuard(() =>
    prisma.negocioProfile.findUnique({
      where: { id: negocioId },
      select: { id: true, recorridos360: { select: { id: true } }, arMarcadores: { select: { id: true } } },
    }),
  )
  if (!lugar) {
    throw new LugarNotFoundError('No se encontró ese lugar')
  }
  for (const r of lugar.recorridos360) await deleteRecorrido(r.id)
  for (const m of lugar.arMarcadores) await deleteMarcador(m.id)
  await withDbGuard(() => prisma.negocioProfile.delete({ where: { id: negocioId } }))
}

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
