import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import { Prisma } from '@prisma/client'
import type { Profile } from 'passport-google-oauth20'
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

export async function findOrCreateGoogleUser(profile: Profile) {
  return withDbGuard(async () => {
    const existingByGoogleId = await prisma.user.findUnique({ where: { googleId: profile.id } })
    if (existingByGoogleId) return existingByGoogleId

    const email = profile.emails?.[0]?.value
    if (!email) {
      throw new Error('Google no devolvió un correo para esta cuenta')
    }

    const existingByEmail = await prisma.user.findUnique({ where: { email } })
    if (existingByEmail) {
      return prisma.user.update({ where: { id: existingByEmail.id }, data: { googleId: profile.id } })
    }

    return prisma.user.create({
      data: {
        email,
        googleId: profile.id,
        nombres: profile.displayName || email,
        avatarUrl: profile.photos?.[0]?.value,
      },
    })
  })
}

export async function findUserById(id: string) {
  return withDbGuard(() => prisma.user.findUnique({ where: { id } }))
}

export function signToken(userId: string) {
  return jwt.sign({ sub: userId }, env.JWT_SECRET, { expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions['expiresIn'] })
}
