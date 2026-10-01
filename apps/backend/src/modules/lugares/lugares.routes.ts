import { Router } from 'express'
import { listPublicos } from './lugares.controller'

/// Público, sin login: el mapa lo consume cualquier visitante.
export const lugaresRouter = Router()

lugaresRouter.get('/', listPublicos)
