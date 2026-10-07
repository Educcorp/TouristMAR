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
  updateNegocioAdmin,
  adminUploadNegocioPortada,
  DatabaseNotReadyError,
  CannotModifyAdminError,
  NegocioNotFoundError,
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

export async function listNegocios(_req: AuthedRequest, res: Response) {
  try {
    const negocios = await listNegociosAll()
    return res.json({
      negocios: negocios.map((n) => ({
        id: n.id,
        ownerId: n.userId,
        nombre: n.nombre,
        categoria: n.categoria,
        estado: n.estado,
        email: n.user.email,
        contacto: n.user.nombres,
        solicitadoEn: n.createdAt,
        archivo360: n.archivo360,
        arMarcador: n.arMarcador,
        arGeo: n.arGeo,
      })),
    })
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

// Texto vacío = borrar el dato (null). Así el admin puede limpiar un campo
// que la empresa llenó mal.
const textoOpcional = (max: number) =>
  z.preprocess((v) => (typeof v === 'string' && v.trim() === '' ? null : v), z.string().max(max).nullable().optional())

const updateNegocioSchema = z.object({
  nombre: z.string().trim().min(1).max(120).optional(),
  categoria: textoOpcional(80),
  descripcion: textoOpcional(350),
  direccion: textoOpcional(200),
  telefono: textoOpcional(40),
  sitioWeb: textoOpcional(200),
  horario: textoOpcional(200),
  latitud: z.number().min(-90).max(90).nullable().optional(),
  longitud: z.number().min(-180).max(180).nullable().optional(),
})

export async function updateNegocio(req: AuthedRequest, res: Response) {
  const parsed = updateNegocioSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Datos inválidos', details: parsed.error.flatten().fieldErrors })
  }
  try {
    const negocio = await updateNegocioAdmin(req.params.negocioId, parsed.data)
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
