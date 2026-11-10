import { Router } from 'express'
import { list, create, rename, remove } from './categorias.controller'
import { requireAuth, requireRole } from '../auth/auth.middleware'

/// Público (se monta en /api/categorias): los formularios de registro y de
/// edición del negocio llenan su lista desplegable con esto.
export const categoriasRouter = Router()

categoriasRouter.get('/', list)

/// Gestión desde el panel admin (se monta en /api/admin/categorias).
export const categoriasAdminRouter = Router()

categoriasAdminRouter.use(requireAuth, requireRole('admin', 'super_admin'))

categoriasAdminRouter.get('/', list)
categoriasAdminRouter.post('/', create)
categoriasAdminRouter.patch('/:id', rename)
categoriasAdminRouter.delete('/:id', remove)
