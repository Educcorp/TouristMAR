import { Response } from 'express'
import { z } from 'zod'
import {
  listNegociosPendientes,
  reviewNegocio,
  getAdminStats,
  listGestionableUsers,
  setUserActive,
  listNegociosAll,
  listAdmins,
  createAdmin,
  deleteAdmin,
  DatabaseNotReadyError,
  CannotModifyAdminError,
} from '../auth/auth.service'
import { toPublicUser } from '../auth/auth.controller'
import type { AuthedRequest } from '../auth/auth.middleware'

export async function dashboard(_req: AuthedRequest, res: Response) {
  try {
    const stats = await getAdminStats()
    return res.json({ stats })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

export async function listPendingNegocios(_req: AuthedRequest, res: Response) {
  try {
    const negocios = await listNegociosPendientes()
    return res.json({
      negocios: negocios.map((n) => ({
        id: n.userId,
        nombre: n.nombre,
        categoria: n.categoria,
        email: n.user.email,
        contacto: n.user.nombres,
        solicitadoEn: n.createdAt,
      })),
    })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

export async function listNegocios(_req: AuthedRequest, res: Response) {
  try {
    const negocios = await listNegociosAll()
    return res.json({
      negocios: negocios.map((n) => ({
        id: n.userId,
        nombre: n.nombre,
        categoria: n.categoria,
        estado: n.estado,
        email: n.user.email,
        contacto: n.user.nombres,
        solicitadoEn: n.createdAt,
      })),
    })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

async function decide(req: AuthedRequest, res: Response, decision: 'aprobado' | 'rechazado') {
  try {
    const negocio = await reviewNegocio(req.params.userId, decision, req.userId!)
    return res.json({ negocio })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(404).json({ error: 'No se encontró ese negocio' })
  }
}

export function approveNegocio(req: AuthedRequest, res: Response) {
  return decide(req, res, 'aprobado')
}

export function rejectNegocio(req: AuthedRequest, res: Response) {
  return decide(req, res, 'rechazado')
}

export async function listUsers(_req: AuthedRequest, res: Response) {
  try {
    const users = await listGestionableUsers()
    return res.json({ users: users.map(toPublicUser) })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

const setActiveSchema = z.object({ activo: z.boolean() })

export async function updateUserActive(req: AuthedRequest, res: Response) {
  const parsed = setActiveSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos' })
  }

  try {
    const user = await setUserActive(req.params.userId, parsed.data.activo)
    return res.json({ user: toPublicUser(user) })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    if (err instanceof CannotModifyAdminError) {
      return res.status(403).json({ error: err.message })
    }
    return res.status(404).json({ error: (err as Error).message })
  }
}

export async function listAdminAccounts(_req: AuthedRequest, res: Response) {
  try {
    const admins = await listAdmins()
    return res.json({
      admins: admins.map((a) => ({
        id: a.id,
        email: a.email,
        name: a.nombres,
        role: a.rol,
        createdAt: a.createdAt,
      })),
    })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

const createAdminSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  nombres: z.string().min(1),
})

export async function createAdminAccount(req: AuthedRequest, res: Response) {
  const parsed = createAdminSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }

  try {
    const admin = await createAdmin(parsed.data)
    return res.status(201).json({
      admin: { id: admin.id, email: admin.email, name: admin.nombres, role: admin.rol, createdAt: admin.createdAt },
    })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(400).json({ error: (err as Error).message })
  }
}

export async function deleteAdminAccount(req: AuthedRequest, res: Response) {
  try {
    await deleteAdmin(req.params.adminId, req.userId!)
    return res.status(204).send()
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    if (err instanceof CannotModifyAdminError) {
      return res.status(403).json({ error: err.message })
    }
    return res.status(404).json({ error: (err as Error).message })
  }
}
