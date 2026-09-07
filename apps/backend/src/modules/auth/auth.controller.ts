import { Request, Response } from 'express'
import { z } from 'zod'
import {
  registerUser,
  validateCredentials,
  signToken,
  findUserById,
  DatabaseNotReadyError,
} from './auth.service'
import type { AuthedRequest } from './auth.middleware'

const credentialsSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
})

const registerSchema = credentialsSchema.extend({
  name: z.string().min(1),
})

export function toPublicUser(user: { id: string; email: string; nombres: string; rol: string; avatarUrl?: string | null }) {
  return { id: user.id, email: user.email, name: user.nombres, role: user.rol, avatarUrl: user.avatarUrl ?? null }
}

export async function register(req: Request, res: Response) {
  const parsed = registerSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }

  try {
    const user = await registerUser(parsed.data.email, parsed.data.password, parsed.data.name)
    const token = signToken(user.id)
    return res.status(201).json({ token, user: toPublicUser(user) })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(400).json({ error: (err as Error).message })
  }
}

export async function login(req: Request, res: Response) {
  const parsed = credentialsSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }

  try {
    const user = await validateCredentials(parsed.data.email, parsed.data.password)
    if (!user) {
      return res.status(401).json({ error: 'Correo o contraseña incorrectos' })
    }
    const token = signToken(user.id)
    return res.json({ token, user: toPublicUser(user) })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

export async function me(req: AuthedRequest, res: Response) {
  try {
    const user = await findUserById(req.userId!)
    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' })
    }
    return res.json({ user: toPublicUser(user) })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}
