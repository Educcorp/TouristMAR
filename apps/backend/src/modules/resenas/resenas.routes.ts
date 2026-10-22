import { Router } from 'express'
import {
  borrar,
  borrarAdmin,
  guardar,
  listAdmin,
  listDeLugar,
  listMias,
  quitarRespuesta,
  responder,
} from './resenas.controller'
import { optionalAuth, requireAuth, requireRole } from '../auth/auth.middleware'

/// Reseñas de los lugares (se monta en /api/resenas). Leer las de un lugar es
/// público; escribir, editar, borrar y responder requiere sesión.
export const resenasRouter = Router()

resenasRouter.get('/lugar/:negocioId', optionalAuth, listDeLugar)
resenasRouter.get('/mias', requireAuth, listMias)
// Los admins moderan, no opinan.
resenasRouter.put('/lugar/:negocioId', requireAuth, requireRole('turista', 'negocio'), guardar)
resenasRouter.delete('/lugar/:negocioId', requireAuth, borrar)
resenasRouter.put('/:id/respuesta', requireAuth, responder)
resenasRouter.delete('/:id/respuesta', requireAuth, quitarRespuesta)

/// Moderación desde el panel admin (se monta en /api/admin/resenas).
export const resenasAdminRouter = Router()

resenasAdminRouter.use(requireAuth, requireRole('admin', 'super_admin'))

resenasAdminRouter.get('/', listAdmin)
resenasAdminRouter.delete('/:id', borrarAdmin)
