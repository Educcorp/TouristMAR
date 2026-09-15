import { Router } from 'express'
import { authRouter } from '../modules/auth/auth.routes'
import { adminRouter } from '../modules/admin/admin.routes'
import { notificationRouter } from '../modules/notifications/notification.routes'

export const apiRouter = Router()

apiRouter.use('/auth', authRouter)
apiRouter.use('/admin', adminRouter)
apiRouter.use('/notifications', notificationRouter)
