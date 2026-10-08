import { Response } from 'express'
import { z } from 'zod'
import {
  listNegociosPendientes,
  listApprovedNegocioUserIds,
  reviewNegocio,
  getAdminStats,
  listGestionableUsers,
  setUserActive,
  listNegociosAll,
  listAdmins,
  createAdmin,
  deleteAdmin,
  getNegocioAdmin,
  adminUploadNegocioPortada,
  DatabaseNotReadyError,
  CannotModifyAdminError,
  NegocioNotFoundError,
} from '../auth/auth.service'
import { toPublicUser } from '../auth/auth.controller'
import {
  setUbicacionNegocio,
  crearLugarAdmin,
  actualizarLugarAdmin,
  eliminarLugarAdmin,
  LugarNotFoundError,
  SinSuperAdminError,
} from '../lugares/lugares.service'
import type { NegocioProfile } from '@prisma/client'
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
    const [negocios, aprobadosPorDueño] = await Promise.all([listNegociosPendientes(), listApprovedNegocioUserIds()])
    return res.json({
      negocios: negocios.map((n) => ({
        id: n.id,
        ownerId: n.userId,
        nombre: n.nombre,
        categoria: n.categoria,
        email: n.user.email,
        contacto: n.user.nombres,
        solicitadoEn: n.createdAt,
        portada: n.portada,
        direccion: n.direccion,
        latitud: n.latitud,
        longitud: n.longitud,
        // Distingue, para el admin, un registro nuevo de una empresa que
        // sugiere un negocio adicional (ya tiene al menos uno aprobado).
        esAdicional: aprobadosPorDueño.has(n.userId),
      })),
    })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

type NegocioConDueño = NegocioProfile & { user: { email: string; nombres: string } }

function toAdminNegocio(n: NegocioConDueño) {
  return {
    id: n.id,
    ownerId: n.userId,
    nombre: n.nombre,
    categoria: n.categoria,
    descripcion: n.descripcion,
    direccion: n.direccion,
    estado: n.estado,
    email: n.user.email,
    contacto: n.user.nombres,
    solicitadoEn: n.createdAt,
    archivo360: n.archivo360,
    arMarcador: n.arMarcador,
    arGeo: n.arGeo,
    latitud: n.latitud,
    longitud: n.longitud,
  }
}

export async function listNegocios(_req: AuthedRequest, res: Response) {
  try {
    const negocios = await listNegociosAll()
    return res.json({ negocios: negocios.map(toAdminNegocio) })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

type NegocioAdmin = Awaited<ReturnType<typeof getNegocioAdmin>>

/// Forma del detalle que consume la página "Detalle de solicitud" del panel.
function toNegocioDetalle(n: NegocioAdmin) {
  return {
    id: n.id,
    ownerId: n.userId,
    nombre: n.nombre,
    categoria: n.categoria,
    descripcion: n.descripcion,
    direccion: n.direccion,
    telefono: n.telefono,
    sitioWeb: n.sitioWeb,
    horario: n.horario,
    portada: n.portada,
    galeria: n.galeria,
    latitud: n.latitud,
    longitud: n.longitud,
    estado: n.estado,
    email: n.user.email,
    contacto: n.user.nombres,
    solicitadoEn: n.createdAt,
    marcadores: n.arMarcadores,
    recorridos: n.recorridos360,
  }
}

function negocioError(res: Response, err: unknown) {
  if (err instanceof DatabaseNotReadyError) {
    return res.status(503).json({ error: err.message })
  }
  if (err instanceof NegocioNotFoundError) {
    return res.status(404).json({ error: err.message })
  }
  return res.status(400).json({ error: (err as Error).message })
}

export async function getNegocio(req: AuthedRequest, res: Response) {
  try {
    const negocio = await getNegocioAdmin(req.params.negocioId)
    return res.json({ negocio: toNegocioDetalle(negocio) })
  } catch (err) {
    return negocioError(res, err)
  }
}

export async function uploadNegocioPortadaAdmin(req: AuthedRequest & { file?: Express.Multer.File }, res: Response) {
  if (!req.file) {
    return res.status(400).json({ error: 'No se recibió ningún archivo' })
  }
  try {
    const negocio = await adminUploadNegocioPortada(req.params.negocioId, {
      buffer: req.file.buffer,
      mimetype: req.file.mimetype,
    })
    return res.json({ negocio: toNegocioDetalle(negocio) })
  } catch (err) {
    return negocioError(res, err)
  }
}

// Pin del mapa: los dos juntos o ninguno (null los quita).
const lugarSchema = z
  .object({
    nombre: z.string().trim().min(1).max(120),
    categoria: z.string().trim().max(60).nullable().optional(),
    descripcion: z.string().trim().max(350).nullable().optional(),
    direccion: z.string().trim().max(200).nullable().optional(),
    telefono: z.string().trim().max(40).nullable().optional(),
    sitioWeb: z.string().trim().max(200).nullable().optional(),
    horario: z.string().trim().max(300).nullable().optional(),
    latitud: z.number().min(-90).max(90).nullable().optional(),
    longitud: z.number().min(-180).max(180).nullable().optional(),
  })

const ambasCoordenadas = (d: { latitud?: number | null; longitud?: number | null }) =>
  (d.latitud === undefined) === (d.longitud === undefined) && (d.latitud === null) === (d.longitud === null)

const crearLugarSchema = lugarSchema.refine(ambasCoordenadas, { message: 'latitud y longitud van juntas' })
const actualizarLugarSchema = lugarSchema.partial().refine(ambasCoordenadas, { message: 'latitud y longitud van juntas' })

/// Un admin registra un lugar que no tiene dueño (FIME, un mirador…).
export async function createLugar(req: AuthedRequest, res: Response) {
  const parsed = crearLugarSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten() })
  }
  try {
    const lugar = await crearLugarAdmin(parsed.data)
    return res.status(201).json({ negocio: toAdminNegocio(lugar) })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    if (err instanceof SinSuperAdminError) {
      return res.status(409).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

/// Datos del lugar que corrige un admin: dirección, descripción y su pin.
export async function updateLugar(req: AuthedRequest, res: Response) {
  const parsed = actualizarLugarSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten() })
  }
  try {
    const lugar = await actualizarLugarAdmin(req.params.negocioId, parsed.data)
    return res.json({ negocio: toAdminNegocio(lugar) })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    if (err instanceof LugarNotFoundError) {
      return res.status(404).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

/// Borra un lugar con sus recorridos 360° y marcadores (y sus archivos).
export async function deleteLugar(req: AuthedRequest, res: Response) {
  try {
    await eliminarLugarAdmin(req.params.negocioId)
    return res.status(204).send()
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    if (err instanceof LugarNotFoundError) {
      return res.status(404).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

const ubicacionSchema = z.object({
  ubicacion: z
    .object({
      latitud: z.number().min(-90).max(90),
      longitud: z.number().min(-180).max(180),
    })
    .nullable(),
})

/// El pin del lugar en el mapa público. Es del lugar, no del recorrido 360°
/// ni de los marcadores: esos solo se ligan al negocio.
export async function updateNegocioUbicacion(req: AuthedRequest, res: Response) {
  const parsed = ubicacionSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Ubicación inválida', details: parsed.error.flatten().fieldErrors })
  }

  try {
    const n = await setUbicacionNegocio(req.params.negocioId, parsed.data.ubicacion)
    return res.json({ negocio: { id: n.id, latitud: n.latitud, longitud: n.longitud } })
  } catch (err) {
    if (err instanceof DatabaseNotReadyError) {
      return res.status(503).json({ error: err.message })
    }
    if (err instanceof LugarNotFoundError) {
      return res.status(404).json({ error: err.message })
    }
    return res.status(500).json({ error: 'Error interno' })
  }
}

async function decide(req: AuthedRequest, res: Response, decision: 'aprobado' | 'rechazado') {
  try {
    const negocio = await reviewNegocio(req.params.negocioId, decision, req.userId!)
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
