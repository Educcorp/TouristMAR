import type { NextFunction, Request, Response } from 'express'
import jwt from 'jsonwebtoken'
import type { rol_enum } from '@prisma/client'
import { env } from '../../config/env'
import { findUserById } from './auth.service'

export interface AuthedRequest extends Request {
  userId?: string
}

export async function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  const header = req.headers.authorization
  const token = header?.startsWith('Bearer ') ? header.slice('Bearer '.length) : null

  if (!token) {
    return res.status(401).json({ error: 'No autorizado' })
  }

  let userId: string
  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as { sub: string }
    userId = payload.sub
  } catch {
    return res.status(401).json({ error: 'Token inválido o expirado' })
  }

  // Un token firmado sigue siendo válido aunque un admin bloquee la cuenta a
  // mitad de sesión — sin esta consulta, una cuenta bloqueada podría seguir
  // usando la API hasta que el token expire por su cuenta. Se corta aquí,
  // en cada request autenticado, en vez de confiar solo en el chequeo al
  // hacer login.
  try {
    const user = await findUserById(userId)
    if (!user) {
      return res.status(401).json({ error: 'Token inválido o expirado' })
    }
    if (user.activo === false) {
      return res.status(403).json({ error: 'Tu cuenta ha sido bloqueada por un administrador', code: 'blocked' })
    }
  } catch {
    return res.status(500).json({ error: 'Error interno' })
  }

  req.userId = userId
  next()
}

export function requireRole(...roles: rol_enum[]) {
  return async (req: AuthedRequest, res: Response, next: NextFunction) => {
    try {
      const user = await findUserById(req.userId!)
      if (!user || !roles.includes(user.rol)) {
        return res.status(403).json({ error: 'No tienes permiso para hacer esto' })
      }
      next()
    } catch {
      return res.status(500).json({ error: 'Error interno' })
    }
  }
}
