import { Router } from 'express'
import { listPublicos } from './lugares.controller'
import { listRaLugares, getRaLugar } from './ra-lugares.controller'

/// Público, sin login: el mapa lo consume cualquier visitante.
export const lugaresRouter = Router()

lugaresRouter.get('/', listPublicos)

/// Coordenadas de los lugares para la RA por ubicación de Unity (se monta en
/// /api/ra/lugares). Público, sin login, igual que marcadores y recorridos.
export const raLugaresRouter = Router()

raLugaresRouter.get('/', listRaLugares)
raLugaresRouter.get('/:id', getRaLugar)
