import { prisma } from '../../config/prisma'
import { withDbGuard } from '../../config/db-guard'

export type NotificationTipo = 'negocio_pendiente' | 'negocio_sugerido' | 'negocio_aprobado' | 'negocio_rechazado' | 'usuario_nuevo'

/// Crea la misma notificación para todos los admins/super_admins vigentes —
/// son pocas cuentas, así que un fan-out simple al crear es más sencillo que
/// modelar destinatarios "por rol" en la tabla.
export async function notifyAdmins(tipo: NotificationTipo, titulo: string, cuerpo: string, negocioId?: string) {
  return withDbGuard(async () => {
    const admins = await prisma.user.findMany({ where: { rol: { in: ['admin', 'super_admin'] } }, select: { id: true } })
    if (admins.length === 0) return

    await prisma.notification.createMany({
      data: admins.map((a) => ({ userId: a.id, tipo, titulo, cuerpo, negocioId })),
    })
  })
}

export async function notifyUser(userId: string, tipo: NotificationTipo, titulo: string, cuerpo: string, negocioId?: string) {
  return withDbGuard(() => prisma.notification.create({ data: { userId, tipo, titulo, cuerpo, negocioId } }))
}

export async function listNotifications(userId: string, limit = 30) {
  return withDbGuard(() =>
    prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit,
    }),
  )
}

export async function countUnreadNotifications(userId: string) {
  return withDbGuard(() => prisma.notification.count({ where: { userId, leida: false } }))
}

export async function markNotificationRead(id: string, userId: string) {
  // `updateMany` en vez de `update` porque filtra por userId a la vez que por
  // id — así una cuenta no puede marcar como leída una notificación ajena
  // solo adivinando el id, sin necesitar una consulta de "dueño" aparte.
  return withDbGuard(() => prisma.notification.updateMany({ where: { id, userId }, data: { leida: true } }))
}

export async function markAllNotificationsRead(userId: string) {
  return withDbGuard(() => prisma.notification.updateMany({ where: { userId, leida: false }, data: { leida: true } }))
}
