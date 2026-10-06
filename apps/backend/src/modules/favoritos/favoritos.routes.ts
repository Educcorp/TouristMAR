import { Router } from 'express'
import { add, listMine, remove } from './favoritos.controller'
import { requireAuth } from '../auth/auth.middleware'

/// "Mis favoritos" del visitante: siempre con sesión iniciada.
export const favoritosRouter = Router()

favoritosRouter.use(requireAuth)

favoritosRouter.get('/', listMine)
favoritosRouter.put('/:negocioId', add)
favoritosRouter.delete('/:negocioId', remove)
