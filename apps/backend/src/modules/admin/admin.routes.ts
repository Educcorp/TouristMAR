import { Router } from 'express'
import multer from 'multer'
import {
  dashboard,
  listPendingNegocios,
  listNegocios,
  approveNegocio,
  rejectNegocio,
  listUsers,
  updateUserActive,
  listAdminAccounts,
  createAdminAccount,
  deleteAdminAccount,
  getNegocio,
  updateNegocio,
  uploadNegocioPortadaAdmin,
} from './admin.controller'
import { requireAuth, requireRole } from '../auth/auth.middleware'

export const adminRouter = Router()

// Misma regla que la portada que sube el dueño (auth.routes.ts).
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    cb(null, file.mimetype.startsWith('image/'))
  },
})

adminRouter.use(requireAuth, requireRole('admin', 'super_admin'))

adminRouter.get('/dashboard', dashboard)

adminRouter.get('/negocios', listNegocios)
adminRouter.get('/negocios/pendientes', listPendingNegocios)
adminRouter.post('/negocios/:negocioId/aprobar', approveNegocio)
adminRouter.post('/negocios/:negocioId/rechazar', rejectNegocio)
// Detalle / edición de una solicitud (o de cualquier negocio). Van después de
// `/negocios/pendientes` para que esa ruta no se tome como un :negocioId.
adminRouter.get('/negocios/:negocioId', getNegocio)
adminRouter.patch('/negocios/:negocioId', updateNegocio)
adminRouter.post('/negocios/:negocioId/portada', upload.single('file'), uploadNegocioPortadaAdmin)

adminRouter.get('/users', listUsers)
adminRouter.patch('/users/:userId/activo', updateUserActive)

adminRouter.get('/admins', listAdminAccounts)
// Solo el super administrador puede dar de alta o quitar otros administradores.
adminRouter.post('/admins', requireRole('super_admin'), createAdminAccount)
adminRouter.delete('/admins/:adminId', requireRole('super_admin'), deleteAdminAccount)
