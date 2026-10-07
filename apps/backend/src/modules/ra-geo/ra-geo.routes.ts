import { Router } from 'express'
import { listPuntosAdmin, crearPuntoAdmin, editarPuntoAdmin, borrarPuntoAdmin } from './ra-geo.controller'
import { requireAuth, requireRole } from '../auth/auth.middleware'

/// Puntos de interés de la RA por geolocalización, desde "Mapa y RA" del
/// panel (se monta en /api/admin/ra-geo). Lo público para la app y Unity
/// sale en GET /api/ra/lugares (ver lugares/ra-lugares.controller.ts).
export const raGeoAdminRouter = Router()

raGeoAdminRouter.use(requireAuth, requireRole('admin', 'super_admin'))

raGeoAdminRouter.get('/lugares/:negocioId/puntos', listPuntosAdmin)
raGeoAdminRouter.post('/lugares/:negocioId/puntos', crearPuntoAdmin)
raGeoAdminRouter.patch('/puntos/:id', editarPuntoAdmin)
raGeoAdminRouter.delete('/puntos/:id', borrarPuntoAdmin)
