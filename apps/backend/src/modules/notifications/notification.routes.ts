import { Router } from 'express'
import { listMine, unreadCount, markOneRead, markAllRead } from './notification.controller'
import { requireAuth } from '../auth/auth.middleware'

export const notificationRouter = Router()

notificationRouter.use(requireAuth)

notificationRouter.get('/', listMine)
notificationRouter.get('/unread-count', unreadCount)
notificationRouter.post('/leer-todas', markAllRead)
notificationRouter.post('/:id/leer', markOneRead)
