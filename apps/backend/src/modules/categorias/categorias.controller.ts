import { Request, Response } from 'express'
import { z } from 'zod'
import {
  listCategorias,
  crearCategoria,
  renombrarCategoria,
  borrarCategoria,
  CategoriaDuplicadaError,
  CategoriaNotFoundError,
} from './categorias.service'
import { DatabaseNotReadyError } from '../../config/db-guard'

const nombreSchema = z.object({ nombre: z.string().trim().min(1).max(60) })

function fail(res: Response, err: unknown) {
  if (err instanceof DatabaseNotReadyError) return res.status(503).json({ error: err.message })
  if (err instanceof CategoriaDuplicadaError) return res.status(409).json({ error: err.message })
  if (err instanceof CategoriaNotFoundError) return res.status(404).json({ error: err.message })
  return res.status(500).json({ error: 'Error interno' })
}

export async function list(_req: Request, res: Response) {
  try {
    return res.json({ categorias: await listCategorias() })
  } catch (err) {
    return fail(res, err)
  }
}

export async function create(req: Request, res: Response) {
  const parsed = nombreSchema.safeParse(req.body)
  if (!parsed.success) return res.status(400).json({ error: 'Escribe un nombre de máximo 60 caracteres' })
  try {
    return res.status(201).json({ categoria: await crearCategoria(parsed.data.nombre) })
  } catch (err) {
    return fail(res, err)
  }
}

export async function rename(req: Request, res: Response) {
  const parsed = nombreSchema.safeParse(req.body)
  if (!parsed.success) return res.status(400).json({ error: 'Escribe un nombre de máximo 60 caracteres' })
  try {
    return res.json({ categoria: await renombrarCategoria(req.params.id, parsed.data.nombre) })
  } catch (err) {
    return fail(res, err)
  }
}

export async function remove(req: Request, res: Response) {
  try {
    await borrarCategoria(req.params.id)
    return res.status(204).send()
  } catch (err) {
    return fail(res, err)
  }
}
