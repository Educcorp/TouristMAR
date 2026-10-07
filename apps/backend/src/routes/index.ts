import { Router } from 'express'
import { authRouter } from '../modules/auth/auth.routes'
import { adminRouter } from '../modules/admin/admin.routes'
import { notificationRouter } from '../modules/notifications/notification.routes'
import { marcadoresRouter, arAdminRouter } from '../modules/ar/ar.routes'
import { recorridosRouter, recorridosAdminRouter } from '../modules/recorridos/recorridos.routes'
import { favoritosRouter } from '../modules/favoritos/favoritos.routes'
import { resenasRouter, resenasAdminRouter } from '../modules/resenas/resenas.routes'
import { lugaresRouter, raLugaresRouter } from '../modules/lugares/lugares.routes'
import { raGeoAdminRouter } from '../modules/ra-geo/ra-geo.routes'

export const apiRouter = Router()

/// GET /api: la base no es un endpoint, pero responde para confirmar que la
/// API está arriba y mostrar las rutas públicas (antes daba "Cannot GET /api").
apiRouter.get('/', (_req, res) => {
  res.json({
    nombre: 'TouristMAR API',
    estado: 'ok',
    endpointsPublicos: {
      lugares: '/api/lugares',
      raLugares: '/api/ra/lugares',
      raLugar: '/api/ra/lugares/{lugarId}',
      raBuscar: '/api/ra/lugares?buscar={texto}',
      marcadores: '/api/marcadores',
      marcadoresDeLugar: '/api/marcadores?negocioId={lugarId}',
      recorridos: '/api/recorridos',
      recorrido: '/api/recorridos/{nombre}',
    },
    documentacion: 'docs/manuals/ra_geolocalizacion.md',
  })
})

apiRouter.use('/auth', authRouter)
// Antes que `/admin`: adminRouter aplica su propio guard a todo lo que pasa
// por él, y los de AR y recorridos ya traen el mismo (requireAuth +
// admin/super_admin).
apiRouter.use('/admin/ar', arAdminRouter)
apiRouter.use('/admin/recorridos', recorridosAdminRouter)
apiRouter.use('/admin/ra-geo', raGeoAdminRouter)
apiRouter.use('/admin/resenas', resenasAdminRouter)
apiRouter.use('/admin', adminRouter)
// Contratos con Unity: GET /api/marcadores (ver ar.controller.ts) y
// GET /api/recorridos (ver recorridos.controller.ts).
apiRouter.use('/marcadores', marcadoresRouter)
apiRouter.use('/recorridos', recorridosRouter)
apiRouter.use('/lugares', lugaresRouter)
// Contrato con Unity para la RA por ubicación (ver ra-lugares.controller.ts).
apiRouter.use('/ra/lugares', raLugaresRouter)
apiRouter.use('/favoritos', favoritosRouter)
apiRouter.use('/resenas', resenasRouter)
apiRouter.use('/notifications', notificationRouter)

// Cualquier otra ruta bajo /api: error en JSON (no la página HTML de Express),
// así Unity y la app siempre pueden leer la respuesta con su parser de JSON.
apiRouter.use((req, res) => {
  res.status(404).json({ error: `No existe ${req.method} /api${req.path}` })
})
