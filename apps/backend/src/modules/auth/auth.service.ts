import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import { OAuth2Client } from 'google-auth-library'
import { Prisma } from '@prisma/client'
import type { Profile } from 'passport-google-oauth20'
import { prisma } from '../../config/prisma'
import { supabase, AVATARS_BUCKET } from '../../config/supabase'
import { env, isGoogleAuthEnabled } from '../../config/env'

const googleClient = isGoogleAuthEnabled ? new OAuth2Client(env.GOOGLE_CLIENT_ID) : null

export class DatabaseNotReadyError extends Error {}
export class GoogleLoginNotAllowedError extends Error {}

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

interface RegisterInput {
  email: string
  password: string
  nombres: string
  rol: 'turista' | 'negocio'
  negocio?: {
    nombre: string
    categoria?: string
  }
}

export async function registerUser(input: RegisterInput) {
  return withDbGuard(async () => {
    const existing = await prisma.user.findUnique({ where: { email: input.email } })
    if (existing) {
      throw new Error('Ya existe una cuenta con ese correo')
    }
    const passwordHash = await bcrypt.hash(input.password, 10)

    return prisma.user.create({
      data: {
        email: input.email,
        passwordHash,
        nombres: input.nombres,
        rol: input.rol,
        negocio:
          input.rol === 'negocio' && input.negocio
            ? { create: { nombre: input.negocio.nombre, categoria: input.negocio.categoria } }
            : undefined,
      },
      include: { negocio: true },
    })
  })
}

export async function validateCredentials(email: string, password: string) {
  return withDbGuard(async () => {
    const user = await prisma.user.findUnique({ where: { email }, include: { negocio: true } })
    if (!user || !user.passwordHash) return null
    const valid = await bcrypt.compare(password, user.passwordHash)
    return valid ? user : null
  })
}

async function resolveGoogleAccount(email: string, googleId: string, profile: { displayName?: string; photo?: string }) {
  const existingByGoogleId = await prisma.user.findUnique({ where: { googleId }, include: { negocio: true } })
  if (existingByGoogleId) return existingByGoogleId

  const existingByEmail = await prisma.user.findUnique({ where: { email }, include: { negocio: true } })

  if (!existingByEmail) {
    // Cuenta nueva vía Google: solo se crean turistas. Los negocios deben
    // registrarse primero con correo/contraseña y ser aprobados por un admin.
    return prisma.user.create({
      data: {
        email,
        googleId,
        rol: 'turista',
        nombres: profile.displayName || email,
        avatarUrl: profile.photo,
      },
      include: { negocio: true },
    })
  }

  if (existingByEmail.rol === 'negocio') {
    if (existingByEmail.negocio?.estado !== 'aprobado') {
      throw new GoogleLoginNotAllowedError(
        'Tu negocio todavía no ha sido aprobado por un administrador. Podrás iniciar sesión con Google en cuanto se apruebe tu cuenta.',
      )
    }
  }

  if (existingByEmail.googleId && existingByEmail.googleId !== googleId) {
    throw new GoogleLoginNotAllowedError('Esta cuenta ya está vinculada a otra cuenta de Google')
  }

  if (!existingByEmail.googleId) {
    return prisma.user.update({
      where: { id: existingByEmail.id },
      data: { googleId },
      include: { negocio: true },
    })
  }

  return existingByEmail
}

export async function findOrCreateGoogleUser(profile: Profile) {
  const email = profile.emails?.[0]?.value
  if (!email) {
    throw new Error('Google no devolvió un correo para esta cuenta')
  }

  return withDbGuard(() =>
    resolveGoogleAccount(email, profile.id, {
      displayName: profile.displayName,
      photo: profile.photos?.[0]?.value,
    }),
  )
}

/// Login con Google desde un cliente que no puede hacer el redirect de
/// navegador (app móvil compilada, ej. el APK de Flutter). El cliente
/// obtiene un idToken con el SDK nativo de Google y lo manda aquí para
/// verificarlo; aplica exactamente las mismas reglas de rol/aprobación que
/// el flujo web (resolveGoogleAccount).
export async function findOrCreateGoogleUserFromMobileToken(idToken: string) {
  if (!googleClient) {
    throw new Error('El login con Google no está configurado en el servidor')
  }

  const ticket = await googleClient.verifyIdToken({ idToken, audience: env.GOOGLE_CLIENT_ID })
  const payload = ticket.getPayload()
  if (!payload || !payload.email) {
    throw new Error('Token de Google inválido')
  }

  return withDbGuard(() =>
    resolveGoogleAccount(payload.email!, payload.sub, {
      displayName: payload.name,
      photo: payload.picture,
    }),
  )
}

export async function findUserById(id: string) {
  return withDbGuard(() => prisma.user.findUnique({ where: { id }, include: { negocio: true } }))
}

export function signToken(userId: string) {
  return jwt.sign({ sub: userId }, env.JWT_SECRET, { expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions['expiresIn'] })
}

export async function updateTuristaProfile(userId: string, data: { nombres?: string; bio?: string }) {
  return withDbGuard(() =>
    prisma.user.update({
      where: { id: userId },
      data: { nombres: data.nombres, bio: data.bio },
      include: { negocio: true },
    }),
  )
}

export interface NegocioProfileInput {
  nombre?: string
  categoria?: string
  descripcion?: string
  direccion?: string
  telefono?: string
  sitioWeb?: string
  horario?: string
  portada?: string
}

export async function updateNegocioProfile(userId: string, data: NegocioProfileInput) {
  return withDbGuard(() =>
    prisma.negocioProfile.update({
      where: { userId },
      data,
    }),
  )
}

const ALLOWED_IMAGE_TYPES: Record<string, string> = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/webp': 'webp',
  'image/gif': 'gif',
}

export async function uploadProfilePhoto(userId: string, file: { buffer: Buffer; mimetype: string }) {
  if (!ALLOWED_IMAGE_TYPES[file.mimetype]) {
    throw new Error('Formato de imagen no soportado (usa PNG, JPG, WEBP o GIF)')
  }

  return withDbGuard(async () => {
    const user = await prisma.user.findUnique({ where: { id: userId }, include: { negocio: true } })
    if (!user) {
      throw new Error('Usuario no encontrado')
    }

    // Un solo archivo fijo por usuario (sin extensión en la ruta, el
    // contentType controla cómo se sirve). Cada subida nueva sobreescribe la
    // anterior en el mismo lugar, así nunca se acumulan fotos viejas sin uso.
    const path = `${userId}/profile-photo`
    const { error: uploadError } = await supabase.storage
      .from(AVATARS_BUCKET)
      .upload(path, file.buffer, { contentType: file.mimetype, upsert: true })

    if (uploadError) {
      throw new Error(`No se pudo subir la imagen: ${uploadError.message}`)
    }

    // Cache-bust: la ruta no cambia entre subidas, así que se agrega un
    // parámetro con la hora para que el navegador no siga mostrando la
    // versión vieja en caché.
    const { data } = supabase.storage.from(AVATARS_BUCKET).getPublicUrl(path)
    const publicUrl = `${data.publicUrl}?v=${Date.now()}`

    if (user.rol === 'negocio' && user.negocio) {
      await prisma.negocioProfile.update({ where: { userId }, data: { portada: publicUrl } })
    } else {
      await prisma.user.update({ where: { id: userId }, data: { avatarUrl: publicUrl } })
    }

    return prisma.user.findUnique({ where: { id: userId }, include: { negocio: true } })
  })
}

export async function listNegociosPendientes() {
  return withDbGuard(() =>
    prisma.negocioProfile.findMany({
      where: { estado: 'pendiente' },
      include: { user: { select: { id: true, email: true, nombres: true, createdAt: true } } },
      orderBy: { createdAt: 'asc' },
    }),
  )
}

export async function reviewNegocio(negocioUserId: string, decision: 'aprobado' | 'rechazado', adminId: string) {
  return withDbGuard(() =>
    prisma.negocioProfile.update({
      where: { userId: negocioUserId },
      data: { estado: decision, revisadoPor: adminId, revisadoEn: new Date() },
    }),
  )
}
