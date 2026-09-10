import { Router } from 'express'
import { listPendingNegocios, approveNegocio, rejectNegocio } from './admin.controller'
import { requireAuth, requireRole } from '../auth/auth.middleware'

export const adminRouter = Router()

adminRouter.use(requireAuth, requireRole('admin', 'super_admin'))

adminRouter.get('/negocios/pendientes', listPendingNegocios)
adminRouter.post('/negocios/:userId/aprobar', approveNegocio)
adminRouter.post('/negocios/:userId/rechazar', rejectNegocio)
