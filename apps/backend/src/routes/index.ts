import { Router } from 'express'
import { authRouter } from '../modules/auth/auth.routes'
import { adminRouter } from '../modules/admin/admin.routes'
import { notificationRouter } from '../modules/notifications/notification.routes'
import { marcadoresRouter, arAdminRouter } from '../modules/ar/ar.routes'

export const apiRouter = Router()

apiRouter.use('/auth', authRouter)
// Antes que `/admin`: adminRouter aplica su propio guard a todo lo que pasa
// por él, y el de AR ya trae el mismo (requireAuth + admin/super_admin).
apiRouter.use('/admin/ar', arAdminRouter)
apiRouter.use('/admin', adminRouter)
// Contrato con Unity: GET /api/marcadores (ver ar.controller.ts).
apiRouter.use('/marcadores', marcadoresRouter)
apiRouter.use('/notifications', notificationRouter)
