import type { NextFunction, Request, Response } from 'express'
import jwt from 'jsonwebtoken'
import type { rol_enum } from '@prisma/client'
import { env } from '../../config/env'
import { findUserById } from './auth.service'

export interface AuthedRequest extends Request {
  userId?: string
}

export function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  const header = req.headers.authorization
  const token = header?.startsWith('Bearer ') ? header.slice('Bearer '.length) : null

  if (!token) {
    return res.status(401).json({ error: 'No autorizado' })
  }

  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as { sub: string }
    req.userId = payload.sub
    next()
  } catch {
    return res.status(401).json({ error: 'Token inválido o expirado' })
  }
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
