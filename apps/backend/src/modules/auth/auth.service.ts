import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import { OAuth2Client } from 'google-auth-library'
import type { Profile } from 'passport-google-oauth20'
import { prisma } from '../../config/prisma'
import { supabase, AVATARS_BUCKET, NEGOCIO_ASSETS_BUCKET } from '../../config/supabase'
import { env, isGoogleAuthEnabled } from '../../config/env'
import { withDbGuard, DatabaseNotReadyError } from '../../config/db-guard'
import { notifyAdmins, notifyUser } from '../notifications/notification.service'

// Re-exportado para no romper `import { DatabaseNotReadyError } from './auth.service'`
// en los controllers — vive en config/db-guard.ts porque notification.service.ts
// también lo necesita y no puede importarlo de aquí sin crear un ciclo.
export { DatabaseNotReadyError }

const googleClient = isGoogleAuthEnabled ? new OAuth2Client(env.GOOGLE_CLIENT_ID) : null

export class GoogleLoginNotAllowedError extends Error {}
export class AccountBlockedError extends Error {}
/// Un negocioId que no existe, o que existe pero no le pertenece al usuario
/// autenticado — se tratan igual (404) para no filtrar si el id existe.
export class NegocioNotFoundError extends Error {}

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

    const user = await prisma.user.create({
      data: {
        email: input.email,
        passwordHash,
        nombres: input.nombres,
        rol: input.rol,
        negocios:
          input.rol === 'negocio' && input.negocio
            ? { create: [{ nombre: input.negocio.nombre, categoria: input.negocio.categoria }] }
            : undefined,
      },
      include: { negocios: true },
    })

    if (input.rol === 'negocio') {
      await notifyAdmins(
        'negocio_pendiente',
        'Nueva solicitud de negocio',
        `${input.nombres} quiere registrar "${input.negocio?.nombre ?? input.nombres}" como negocio`,
        user.negocios[0]?.id,
      )
    } else {
      await notifyAdmins('usuario_nuevo', 'Nuevo usuario registrado', `${input.nombres} (${input.email}) se registró como turista`)
    }

    return user
  })
}

export async function validateCredentials(email: string, password: string) {
  return withDbGuard(async () => {
    const user = await prisma.user.findUnique({ where: { email }, include: { negocios: true } })
    if (!user || !user.passwordHash) return null
    const valid = await bcrypt.compare(password, user.passwordHash)
    if (!valid) return null
    if (user.activo === false) {
      throw new AccountBlockedError('Tu cuenta ha sido bloqueada por un administrador')
    }
    return user
  })
}

async function resolveGoogleAccount(email: string, googleId: string, profile: { displayName?: string; photo?: string }) {
  const existingByGoogleId = await prisma.user.findUnique({ where: { googleId }, include: { negocios: true } })
  if (existingByGoogleId) {
    if (existingByGoogleId.activo === false) {
      throw new AccountBlockedError('Tu cuenta ha sido bloqueada por un administrador')
    }
    return existingByGoogleId
  }

  const existingByEmail = await prisma.user.findUnique({ where: { email }, include: { negocios: true } })

  if (existingByEmail && existingByEmail.activo === false) {
    throw new AccountBlockedError('Tu cuenta ha sido bloqueada por un administrador')
  }

  if (!existingByEmail) {
    // Cuenta nueva vía Google: solo se crean turistas. Los negocios deben
    // registrarse primero con correo/contraseña y ser aprobados por un admin.
    const nombres = profile.displayName || email
    const user = await prisma.user.create({
      data: {
        email,
        googleId,
        rol: 'turista',
        nombres,
        avatarUrl: profile.photo,
      },
      include: { negocios: true },
    })
    await notifyAdmins('usuario_nuevo', 'Nuevo usuario registrado', `${nombres} (${email}) se registró como turista`)
    return user
  }

  if (existingByEmail.rol === 'negocio') {
    const tieneAprobado = existingByEmail.negocios.some((n) => n.estado === 'aprobado')
    if (!tieneAprobado) {
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
      include: { negocios: true },
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
  return withDbGuard(() => prisma.user.findUnique({ where: { id }, include: { negocios: true } }))
}

export function signToken(userId: string) {
  return jwt.sign({ sub: userId }, env.JWT_SECRET, { expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions['expiresIn'] })
}

export async function updateTuristaProfile(userId: string, data: { nombres?: string; bio?: string }) {
  return withDbGuard(() =>
    prisma.user.update({
      where: { id: userId },
      data: { nombres: data.nombres, bio: data.bio },
      include: { negocios: true },
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

/// Confirma que `negocioId` existe y le pertenece a `userId`. Todas las
/// mutaciones sobre un negocio puntual (editar, subir portada/galería,
/// aprobar/rechazar queda aparte porque eso lo hace un admin, no el dueño)
/// pasan por aquí primero — ahora que una cuenta puede tener varios negocios
/// ya no alcanza con `where: { userId }` para identificar cuál.
async function assertOwnedNegocio(negocioId: string, userId: string) {
  const negocio = await prisma.negocioProfile.findUnique({ where: { id: negocioId } })
  if (!negocio || negocio.userId !== userId) {
    throw new NegocioNotFoundError('No se encontró ese negocio')
  }
  return negocio
}

export async function updateNegocioProfile(negocioId: string, userId: string, data: NegocioProfileInput) {
  return withDbGuard(async () => {
    await assertOwnedNegocio(negocioId, userId)
    return prisma.negocioProfile.update({ where: { id: negocioId }, data })
  })
}

const ALLOWED_IMAGE_TYPES: Record<string, string> = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/webp': 'webp',
  'image/gif': 'gif',
}

/// Solo para el avatar de turista — la portada de un negocio se sube con
/// [uploadNegocioPortada], que exige un negocioId puntual.
export async function uploadProfilePhoto(userId: string, file: { buffer: Buffer; mimetype: string }) {
  if (!ALLOWED_IMAGE_TYPES[file.mimetype]) {
    throw new Error('Formato de imagen no soportado (usa PNG, JPG, WEBP o GIF)')
  }

  return withDbGuard(async () => {
    const user = await prisma.user.findUnique({ where: { id: userId } })
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

    await prisma.user.update({ where: { id: userId }, data: { avatarUrl: publicUrl } })

    return prisma.user.findUnique({ where: { id: userId }, include: { negocios: true } })
  })
}

export async function uploadNegocioPortada(negocioId: string, userId: string, file: { buffer: Buffer; mimetype: string }) {
  if (!ALLOWED_IMAGE_TYPES[file.mimetype]) {
    throw new Error('Formato de imagen no soportado (usa PNG, JPG, WEBP o GIF)')
  }

  return withDbGuard(async () => {
    await assertOwnedNegocio(negocioId, userId)

    // Un archivo fijo por negocio (no por usuario, ya que un dueño puede
    // tener varios) — cada subida nueva sobreescribe la portada anterior de
    // ESE negocio en particular.
    const path = `${negocioId}/portada`
    const { error: uploadError } = await supabase.storage
      .from(NEGOCIO_ASSETS_BUCKET)
      .upload(path, file.buffer, { contentType: file.mimetype, upsert: true })

    if (uploadError) {
      throw new Error(`No se pudo subir la imagen: ${uploadError.message}`)
    }

    const { data } = supabase.storage.from(NEGOCIO_ASSETS_BUCKET).getPublicUrl(path)
    const publicUrl = `${data.publicUrl}?v=${Date.now()}`

    return prisma.negocioProfile.update({ where: { id: negocioId }, data: { portada: publicUrl } })
  })
}

export async function addNegocioGaleriaImage(
  negocioId: string,
  userId: string,
  file: { buffer: Buffer; mimetype: string; originalname: string },
) {
  if (!ALLOWED_IMAGE_TYPES[file.mimetype]) {
    throw new Error('Formato de imagen no soportado (usa PNG, JPG, WEBP o GIF)')
  }

  return withDbGuard(async () => {
    await assertOwnedNegocio(negocioId, userId)

    const ext = ALLOWED_IMAGE_TYPES[file.mimetype]
    // Ruta única por subida (a diferencia de portada/avatar): la galería
    // acumula varias fotos en vez de reemplazar una sola.
    const path = `${negocioId}/galeria/${Date.now()}.${ext}`

    const { error: uploadError } = await supabase.storage
      .from(NEGOCIO_ASSETS_BUCKET)
      .upload(path, file.buffer, { contentType: file.mimetype })

    if (uploadError) {
      throw new Error(`No se pudo subir la imagen: ${uploadError.message}`)
    }

    const { data } = supabase.storage.from(NEGOCIO_ASSETS_BUCKET).getPublicUrl(path)

    return prisma.negocioProfile.update({
      where: { id: negocioId },
      data: { galeria: { push: data.publicUrl } },
    })
  })
}

export async function removeNegocioGaleriaImage(negocioId: string, userId: string, url: string) {
  return withDbGuard(async () => {
    const negocio = await assertOwnedNegocio(negocioId, userId)

    return prisma.negocioProfile.update({
      where: { id: negocioId },
      data: { galeria: negocio.galeria.filter((img) => img !== url) },
    })
  })
}

export interface SuggestNegocioInput {
  nombre: string
  categoria?: string
  descripcion?: string
  direccion?: string
}

/// Una cuenta de negocio ya aprobada sugiere un negocio adicional — cae en la
/// misma cola de revisión que un registro nuevo (mismo `estado: 'pendiente'`,
/// misma tabla), solo que ligado a un `userId` que ya tiene al menos un
/// negocio aprobado. Se exige eso para no dejar que una cuenta sin vetear
/// nunca amontone solicitudes.
export async function suggestNegocio(userId: string, input: SuggestNegocioInput) {
  return withDbGuard(async () => {
    const user = await prisma.user.findUnique({ where: { id: userId }, include: { negocios: true } })
    if (!user || user.rol !== 'negocio') {
      throw new Error('Solo las cuentas de negocio pueden sugerir un negocio nuevo')
    }
    if (!user.negocios.some((n) => n.estado === 'aprobado')) {
      throw new Error('Necesitas tener al menos un negocio aprobado antes de sugerir uno nuevo')
    }

    const negocio = await prisma.negocioProfile.create({
      data: {
        userId,
        nombre: input.nombre,
        categoria: input.categoria,
        descripcion: input.descripcion,
        direccion: input.direccion,
      },
    })

    await notifyAdmins(
      'negocio_sugerido',
      'Nuevo negocio sugerido',
      `${user.nombres} sugirió agregar "${input.nombre}"`,
      negocio.id,
    )

    return negocio
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

/// Ids de dueños que ya tienen al menos un negocio aprobado — usado por el
/// admin para distinguir, en la cola de solicitudes, un registro nuevo de
/// una sugerencia de negocio adicional de una cuenta ya vetada.
export async function listApprovedNegocioUserIds() {
  return withDbGuard(async () => {
    const rows = await prisma.negocioProfile.findMany({ where: { estado: 'aprobado' }, select: { userId: true } })
    return new Set(rows.map((r) => r.userId))
  })
}

export async function reviewNegocio(negocioId: string, decision: 'aprobado' | 'rechazado', adminId: string) {
  return withDbGuard(async () => {
    const negocio = await prisma.negocioProfile.update({
      where: { id: negocioId },
      data: { estado: decision, revisadoPor: adminId, revisadoEn: new Date() },
    })

    await notifyUser(
      negocio.userId,
      decision === 'aprobado' ? 'negocio_aprobado' : 'negocio_rechazado',
      decision === 'aprobado' ? '¡Tu negocio fue aprobado!' : 'Tu negocio fue rechazado',
      decision === 'aprobado'
        ? `"${negocio.nombre}" ya está activo en TouristMAR.`
        : `Tu solicitud para "${negocio.nombre}" fue rechazada.`,
      negocio.id,
    )

    return negocio
  })
}

export class CannotModifyAdminError extends Error {}
export class SuperAdminAlreadyExistsError extends Error {}

export async function getAdminStats() {
  return withDbGuard(async () => {
    const [turistas, negociosActivos, negociosPendientes, negociosTotal] = await Promise.all([
      prisma.user.count({ where: { rol: 'turista' } }),
      prisma.negocioProfile.count({ where: { estado: 'aprobado' } }),
      prisma.negocioProfile.count({ where: { estado: 'pendiente' } }),
      prisma.negocioProfile.count(),
    ])
    return { turistas, negociosActivos, negociosPendientes, negociosTotal }
  })
}

export async function listGestionableUsers() {
  return withDbGuard(() =>
    prisma.user.findMany({
      where: { rol: { in: ['turista', 'negocio'] } },
      include: { negocios: true },
      orderBy: { createdAt: 'desc' },
    }),
  )
}

export async function setUserActive(userId: string, activo: boolean) {
  return withDbGuard(async () => {
    const user = await prisma.user.findUnique({ where: { id: userId } })
    if (!user) {
      throw new Error('Usuario no encontrado')
    }
    if (user.rol === 'admin' || user.rol === 'super_admin') {
      throw new CannotModifyAdminError('No puedes bloquear a un administrador')
    }
    return prisma.user.update({ where: { id: userId }, data: { activo }, include: { negocios: true } })
  })
}

export async function listNegociosAll() {
  return withDbGuard(() =>
    prisma.negocioProfile.findMany({
      include: { user: { select: { id: true, email: true, nombres: true, createdAt: true } } },
      orderBy: { createdAt: 'desc' },
    }),
  )
}

export async function listAdmins() {
  return withDbGuard(() =>
    prisma.user.findMany({
      where: { rol: { in: ['admin', 'super_admin'] } },
      orderBy: { createdAt: 'asc' },
    }),
  )
}

export interface CreateAdminInput {
  email: string
  password: string
  nombres: string
}

export async function createAdmin(input: CreateAdminInput) {
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
        rol: 'admin',
      },
    })
  })
}

export async function deleteAdmin(adminId: string, requestedBy: string) {
  return withDbGuard(async () => {
    const target = await prisma.user.findUnique({ where: { id: adminId } })
    if (!target || target.rol === 'turista' || target.rol === 'negocio') {
      throw new Error('No se encontró ese administrador')
    }
    if (target.rol === 'super_admin') {
      throw new CannotModifyAdminError('No se puede eliminar al super administrador')
    }
    if (target.id === requestedBy) {
      throw new CannotModifyAdminError('No puedes eliminar tu propia cuenta de administrador')
    }
    await prisma.user.delete({ where: { id: adminId } })
  })
}
