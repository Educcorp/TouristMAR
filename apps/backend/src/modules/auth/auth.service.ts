import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import { Prisma } from '@prisma/client'
import { prisma } from '../../config/prisma'
import { env } from '../../config/env'

export class DatabaseNotReadyError extends Error {}

async function withDbGuard<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn()
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2021') {
      throw new DatabaseNotReadyError(
        'La tabla de usuarios no existe todavía en la base de datos. Corre las migraciones de Prisma (npx prisma migrate dev).',
      )
    }
    throw err
  }
}

export async function registerUser(email: string, password: string, nombres: string) {
  return withDbGuard(async () => {
    const existing = await prisma.user.findUnique({ where: { email } })
    if (existing) {
      throw new Error('Ya existe una cuenta con ese correo')
    }
    const passwordHash = await bcrypt.hash(password, 10)
    return prisma.user.create({ data: { email, passwordHash, nombres } })
  })
}

export async function validateCredentials(email: string, password: string) {
  return withDbGuard(async () => {
    const user = await prisma.user.findUnique({ where: { email } })
    if (!user || !user.passwordHash) return null
    const valid = await bcrypt.compare(password, user.passwordHash)
    return valid ? user : null
  })
}

export function signToken(userId: string) {
  return jwt.sign({ sub: userId }, env.JWT_SECRET, { expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions['expiresIn'] })
}
