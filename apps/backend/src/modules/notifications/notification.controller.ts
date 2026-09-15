import { Response } from 'express'
import type { Notification } from '@prisma/client'
import {
  listNotifications,
  countUnreadNotifications,
  markNotificationRead,
  markAllNotificationsRead,
} from './notification.service'
import { DatabaseNotReadyError } from '../../config/db-guard'
import type { AuthedRequest } from '../auth/auth.middleware'

function toPublicNotification(n: Notification) {
  return {
    id: n.id,
    tipo: n.tipo,
    titulo: n.titulo,
    cuerpo: n.cuerpo,
    negocioId: n.negocioId,
    leida: n.leida,
    createdAt: n.createdAt,
  }
}

export async function listMine(req: AuthedRequest, res: Response) {
  try {
    const notifications = await listNotifications(req.userId!)
    return res.json({ notifications: notifications.map(toPublicNotification) })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

export async function unreadCount(req: AuthedRequest, res: Response) {
  try {
    const count = await countUnreadNotifications(req.userId!)
    return res.json({ count })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

export async function markOneRead(req: AuthedRequest, res: Response) {
  try {
    await markNotificationRead(req.params.id, req.userId!)
    return res.status(204).send()
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

export async function markAllRead(req: AuthedRequest, res: Response) {
  try {
    await markAllNotificationsRead(req.userId!)
    return res.status(204).send()
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}
