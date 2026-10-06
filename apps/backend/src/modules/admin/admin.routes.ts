import { Router } from 'express'
import {
  dashboard,
  listPendingNegocios,
  listNegocios,
  approveNegocio,
  rejectNegocio,
  updateNegocioUbicacion,
  createLugar,
  updateLugar,
  deleteLugar,
  listUsers,
  updateUserActive,
  listAdminAccounts,
  createAdminAccount,
  deleteAdminAccount,
} from './admin.controller'
import { requireAuth, requireRole } from '../auth/auth.middleware'

export const adminRouter = Router()

adminRouter.use(requireAuth, requireRole('admin', 'super_admin'))

adminRouter.get('/dashboard', dashboard)

adminRouter.get('/negocios', listNegocios)
adminRouter.get('/negocios/pendientes', listPendingNegocios)
adminRouter.post('/negocios/:negocioId/aprobar', approveNegocio)
adminRouter.post('/negocios/:negocioId/rechazar', rejectNegocio)
adminRouter.put('/negocios/:negocioId/ubicacion', updateNegocioUbicacion)
adminRouter.patch('/negocios/:negocioId', updateLugar)
adminRouter.delete('/negocios/:negocioId', deleteLugar)
// Lugar sin dueño (lo registra el admin; queda a nombre del super admin).
adminRouter.post('/lugares', createLugar)

adminRouter.get('/users', listUsers)
adminRouter.patch('/users/:userId/activo', updateUserActive)

adminRouter.get('/admins', listAdminAccounts)
// Solo el super administrador puede dar de alta o quitar otros administradores.
adminRouter.post('/admins', requireRole('super_admin'), createAdminAccount)
adminRouter.delete('/admins/:adminId', requireRole('super_admin'), deleteAdminAccount)
