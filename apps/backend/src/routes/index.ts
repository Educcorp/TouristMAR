import { Router } from 'express'
import { authRouter } from '../modules/auth/auth.routes'
import { adminRouter } from '../modules/admin/admin.routes'
import { notificationRouter } from '../modules/notifications/notification.routes'
import { marcadoresRouter, arAdminRouter } from '../modules/ar/ar.routes'
import { recorridosRouter, recorridosAdminRouter } from '../modules/recorridos/recorridos.routes'

export const apiRouter = Router()

apiRouter.use('/auth', authRouter)
// Antes que `/admin`: adminRouter aplica su propio guard a todo lo que pasa
// por él, y los de AR y recorridos ya traen el mismo (requireAuth +
// admin/super_admin).
apiRouter.use('/admin/ar', arAdminRouter)
apiRouter.use('/admin/recorridos', recorridosAdminRouter)
apiRouter.use('/admin', adminRouter)
// Contratos con Unity: GET /api/marcadores (ver ar.controller.ts) y
// GET /api/recorridos (ver recorridos.controller.ts).
apiRouter.use('/marcadores', marcadoresRouter)
apiRouter.use('/recorridos', recorridosRouter)
apiRouter.use('/notifications', notificationRouter)
