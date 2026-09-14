import { Request, Response } from 'express'
import { z } from 'zod'
import type { NegocioProfile, User } from '@prisma/client'
import {
  registerUser,
  validateCredentials,
  signToken,
  findUserById,
  updateTuristaProfile,
  updateNegocioProfile,
  uploadProfilePhoto,
  findOrCreateGoogleUserFromMobileToken,
  DatabaseNotReadyError,
  GoogleLoginNotAllowedError,
  AccountBlockedError,
} from './auth.service'
import type { AuthedRequest } from './auth.middleware'

const credentialsSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
})

const registerSchema = credentialsSchema
  .extend({
    name: z.string().min(1),
    rol: z.enum(['turista', 'negocio']).default('turista'),
    categoria: z.string().min(1).optional(),
  })
  .refine((data) => data.rol !== 'negocio' || data.name.trim().length > 0, {
    message: 'El nombre del negocio es requerido',
    path: ['name'],
  })

const googleMobileSchema = z.object({
  idToken: z.string().min(1),
})

const profileSchema = z.object({
  nombres: z.string().min(1).optional(),
  bio: z.string().max(200).optional(),
  nombre: z.string().min(1).optional(),
  categoria: z.string().optional(),
  descripcion: z.string().max(350).optional(),
  direccion: z.string().optional(),
  telefono: z.string().optional(),
  sitioWeb: z.string().optional(),
  horario: z.string().optional(),
  portada: z.string().optional(),
})

type UserWithNegocio = User & { negocio: NegocioProfile | null }

export function toPublicUser(user: UserWithNegocio) {
  return {
    id: user.id,
    email: user.email,
    name: user.nombres,
    role: user.rol,
    activo: user.activo,
    createdAt: user.createdAt,
    avatarUrl: user.avatarUrl ?? null,
    bio: user.bio ?? null,
    negocio: user.negocio
      ? {
          nombre: user.negocio.nombre,
          categoria: user.negocio.categoria,
          descripcion: user.negocio.descripcion,
          direccion: user.negocio.direccion,
          telefono: user.negocio.telefono,
          sitioWeb: user.negocio.sitioWeb,
          horario: user.negocio.horario,
          portada: user.negocio.portada,
          archivo360: user.negocio.archivo360,
          arMarcador: user.negocio.arMarcador,
          arGeo: user.negocio.arGeo,
          estado: user.negocio.estado,
        }
      : null,
  }
}

export async function register(req: Request, res: Response) {
  const parsed = registerSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }

  try {
    const { email, password, name, rol, categoria } = parsed.data
    const user = await registerUser({
      email,
      password,
      nombres: name,
      rol,
      negocio: rol === 'negocio' ? { nombre: name, categoria } : undefined,
    })
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
    if (err instanceof AccountBlockedError) {
      return res.status(403).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

export async function googleMobileLogin(req: Request, res: Response) {
  const parsed = googleMobileSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }

  try {
    const user = await findOrCreateGoogleUserFromMobileToken(parsed.data.idToken)
    const token = signToken(user.id)
    return res.json({ token, user: toPublicUser(user) })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    if (err instanceof GoogleLoginNotAllowedError || err instanceof AccountBlockedError) {
      return res.status(403).json({ error: err.message })
    }
    return res.status(401).json({ error: (err as Error).message })
  }
}

export async function uploadAvatar(req: AuthedRequest & { file?: Express.Multer.File }, res: Response) {
  if (!req.file) {
    return res.status(400).json({ error: 'No se recibió ningún archivo' })
  }

  try {
    const updated = await uploadProfilePhoto(req.userId!, {
      buffer: req.file.buffer,
      mimetype: req.file.mimetype,
    })
    if (!updated) {
      return res.status(404).json({ error: 'Usuario no encontrado' })
    }
    return res.json({ user: toPublicUser(updated) })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(400).json({ error: (err as Error).message })
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

export async function updateProfile(req: AuthedRequest, res: Response) {
  const parsed = profileSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }

  try {
    const current = await findUserById(req.userId!)
    if (!current) {
      return res.status(404).json({ error: 'Usuario no encontrado' })
    }

    if (current.rol === 'negocio') {
      if (!current.negocio) {
        return res.status(404).json({ error: 'Este negocio no tiene un perfil creado' })
      }
      const { nombre, categoria, descripcion, direccion, telefono, sitioWeb, horario, portada } = parsed.data
      await updateNegocioProfile(current.id, { nombre, categoria, descripcion, direccion, telefono, sitioWeb, horario, portada })
    } else {
      const { nombres, bio } = parsed.data
      await updateTuristaProfile(current.id, { nombres, bio })
    }

    const updated = await findUserById(current.id)
    return res.json({ user: toPublicUser(updated!) })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}
