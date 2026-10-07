import { prisma } from '../../config/prisma'
import { withDbGuard } from '../../config/db-guard'
import { NegocioNotFoundError } from '../auth/auth.service'
import { notifyAdmins, notifyUser } from '../notifications/notification.service'

/// No se puede solicitar en el estado actual del negocio (sin ubicación).
export class SolicitudInvalidaError extends Error {}
/// Ya tiene recorrido, ya hay una solicitud pendiente o ya se atendió.
export class SolicitudConflictoError extends Error {}
export class SolicitudNotFoundError extends Error {}

export type DecisionSolicitud = 'completada' | 'rechazada'

async function negocioPropio(negocioId: string, userId: string) {
  const negocio = await prisma.negocioProfile.findUnique({ where: { id: negocioId } })
  if (!negocio || negocio.userId !== userId) {
    throw new NegocioNotFoundError('No se encontró ese negocio')
  }
  return negocio
}

/// Las notificaciones son un extra: si fallan, la solicitud ya quedó guardada.
async function avisar(fn: () => Promise<unknown>) {
  try {
    await fn()
  } catch (err) {
    console.error('No se pudo crear la notificación de recorrido 360°', err)
  }
}

/// Lo que ve el negocio en "Editar negocio": si ya tiene recorrido 360° (de
/// cualquier estado: si un admin lo está armando, tampoco hace falta pedirlo
/// otra vez) y su solicitud más reciente.
export async function estadoRecorridoNegocio(negocioId: string, userId: string) {
  return withDbGuard(async () => {
    await negocioPropio(negocioId, userId)
    const [recorridos, solicitud] = await Promise.all([
      prisma.recorrido360.count({ where: { negocioId } }),
      prisma.solicitudRecorrido360.findFirst({ where: { negocioId }, orderBy: { createdAt: 'desc' } }),
    ])
    return { tieneRecorrido: recorridos > 0, solicitud }
  })
}

/// El negocio pide su recorrido 360°. Hace falta que ya tenga su pin en el
/// mapa (es a donde va el equipo a tomar las fotos).
export async function solicitarRecorrido(negocioId: string, userId: string, mensaje = '') {
  return withDbGuard(async () => {
    const negocio = await negocioPropio(negocioId, userId)
    if (negocio.latitud == null || negocio.longitud == null) {
      throw new SolicitudInvalidaError('Primero marca tu negocio en el mapa y guarda los cambios')
    }
    if ((await prisma.recorrido360.count({ where: { negocioId } })) > 0) {
      throw new SolicitudConflictoError('Tu negocio ya tiene un recorrido 360°')
    }
    const pendiente = await prisma.solicitudRecorrido360.findFirst({ where: { negocioId, estado: 'pendiente' } })
    if (pendiente) {
      throw new SolicitudConflictoError('Ya enviaste una solicitud de recorrido 360°; está pendiente de revisión')
    }

    const solicitud = await prisma.solicitudRecorrido360.create({ data: { negocioId, mensaje } })
    await avisar(() =>
      notifyAdmins(
        'recorrido_solicitado',
        'Solicitud de recorrido 360°',
        `${negocio.nombre} solicitó un recorrido 360° de su negocio.`,
        negocioId,
      ),
    )
    return solicitud
  })
}

const includeNegocio = {
  negocio: {
    select: {
      id: true,
      nombre: true,
      categoria: true,
      direccion: true,
      telefono: true,
      latitud: true,
      longitud: true,
      user: { select: { nombres: true, apellidos: true, email: true } },
    },
  },
}

/// Para la sección "Solicitudes" del admin; las pendientes primero y, dentro
/// de cada grupo, las más antiguas primero (las que llevan más esperando).
export async function listSolicitudes(estado?: 'pendiente' | DecisionSolicitud) {
  return withDbGuard(() =>
    prisma.solicitudRecorrido360.findMany({
      where: estado ? { estado } : undefined,
      orderBy: [{ estado: 'asc' }, { createdAt: 'asc' }],
      include: includeNegocio,
    }),
  )
}

/// El admin marca una solicitud pendiente como completada (ya subió el
/// recorrido) o rechazada (con una nota para el negocio).
export async function atenderSolicitud(id: string, decision: DecisionSolicitud, nota: string, adminId: string) {
  return withDbGuard(async () => {
    const solicitud = await prisma.solicitudRecorrido360.findUnique({ where: { id }, include: includeNegocio })
    if (!solicitud) throw new SolicitudNotFoundError('No se encontró esa solicitud')
    if (solicitud.estado !== 'pendiente') throw new SolicitudConflictoError('Esa solicitud ya fue atendida')

    const actualizada = await prisma.solicitudRecorrido360.update({
      where: { id },
      data: { estado: decision, nota, atendidaPor: adminId, atendidaEn: new Date() },
      include: includeNegocio,
    })
    const negocio = await prisma.negocioProfile.findUnique({ where: { id: solicitud.negocioId }, select: { userId: true } })
    if (negocio) {
      const nombre = solicitud.negocio.nombre
      await avisar(() =>
        decision === 'completada'
          ? notifyUser(
              negocio.userId,
              'recorrido_listo',
              'Solicitud de recorrido 360° atendida',
              // Al crear el recorrido todavía no tiene fotos: no se promete
              // que ya lo vean los visitantes.
              `Un administrador ya registró el recorrido 360° de ${nombre}.`,
              solicitud.negocioId,
            )
          : notifyUser(
              negocio.userId,
              'recorrido_rechazado',
              'Solicitud de recorrido 360° no aprobada',
              nota ? `${nombre}: ${nota}` : `Por ahora no se pudo agendar el recorrido 360° de ${nombre}.`,
              solicitud.negocioId,
            ),
      )
    }
    return actualizada
  })
}

/// Al crear un recorrido para un negocio, sus solicitudes pendientes quedan
/// atendidas solas (el admin no tiene que volver a "Solicitudes").
export async function completarSolicitudesDeNegocio(negocioId: string, adminId: string) {
  return withDbGuard(async () => {
    const pendientes = await prisma.solicitudRecorrido360.findMany({
      where: { negocioId, estado: 'pendiente' },
      select: { id: true },
    })
    for (const s of pendientes) {
      await atenderSolicitud(s.id, 'completada', '', adminId)
    }
    return pendientes.length
  })
}
