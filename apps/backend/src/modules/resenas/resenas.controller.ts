import { Response } from 'express'
import { z } from 'zod'
import {
  borrarResenaAdmin,
  borrarResenaPropia,
  esUuid,
  guardarResena,
  listMisResenas,
  listResenasAdmin,
  listResenasDeNegocio,
  resumenDeNegocio,
  responderResena,
} from './resenas.service'
import { DatabaseNotReadyError } from '../../config/db-guard'
import type { AuthedRequest } from '../auth/auth.middleware'

function fail(res: Response, err: unknown) {
  if (err instanceof DatabaseNotReadyError) {
    return res.status(503).json({ error: err.message })
  }
  return res.status(500).json({ error: 'Error interno' })
}

/// Nombre y la inicial del apellido ("Carlos M."): la reseña es pública y no
/// debe exponer el nombre completo ni el correo de nadie.
function nombrePublico(nombres: string, apellidos: string | null) {
  const inicial = apellidos?.trim() ? ` ${apellidos.trim()[0].toUpperCase()}.` : ''
  return `${nombres.trim()}${inicial}`
}

const guardarSchema = z.object({
  estrellas: z.coerce.number().int().min(1).max(5),
  comentario: z
    .string()
    .trim()
    .max(1000)
    .nullish()
    .transform((v) => (v ? v : null)),
})

const respuestaSchema = z.object({
  respuesta: z.string().trim().min(1).max(1000),
})

/// Público: reseñas de un lugar con el resumen (promedio, total, distribución).
/// Con sesión, marca cuál es la del propio usuario (`mia`).
export async function listDeLugar(req: AuthedRequest, res: Response) {
  const { negocioId } = req.params
  if (!esUuid(negocioId)) return res.status(400).json({ error: 'Lugar inválido' })
  try {
    const [resumen, resenas] = await Promise.all([resumenDeNegocio(negocioId), listResenasDeNegocio(negocioId)])
    return res.json({
      resumen,
      resenas: resenas.map((r) => ({
        id: r.id,
        estrellas: r.estrellas,
        comentario: r.comentario,
        respuesta: r.respuesta,
        respuestaEn: r.respuestaEn,
        createdAt: r.createdAt,
        autor: { nombre: nombrePublico(r.user.nombres, r.user.apellidos), avatarUrl: r.user.avatarUrl },
        mia: req.userId !== undefined && r.userId === req.userId,
      })),
    })
  } catch (err) {
    return fail(res, err)
  }
}

export async function guardar(req: AuthedRequest, res: Response) {
  const { negocioId } = req.params
  if (!esUuid(negocioId)) return res.status(400).json({ error: 'Lugar inválido' })
  const parsed = guardarSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Elige de 1 a 5 estrellas y escribe un comentario de máximo 1000 caracteres' })
  }
  try {
    const resultado = await guardarResena(req.userId!, negocioId, parsed.data.estrellas, parsed.data.comentario)
    if (resultado === 'no_encontrado') return res.status(404).json({ error: 'Lugar no encontrado' })
    if (resultado === 'propio') return res.status(403).json({ error: 'No puedes reseñar tu propio negocio' })
    return res.status(204).send()
  } catch (err) {
    return fail(res, err)
  }
}

export async function borrar(req: AuthedRequest, res: Response) {
  const { negocioId } = req.params
  if (!esUuid(negocioId)) return res.status(400).json({ error: 'Lugar inválido' })
  try {
    await borrarResenaPropia(req.userId!, negocioId)
    return res.status(204).send()
  } catch (err) {
    return fail(res, err)
  }
}

export async function listMias(req: AuthedRequest, res: Response) {
  try {
    const resenas = await listMisResenas(req.userId!)
    return res.json({
      resenas: resenas.map((r) => ({
        id: r.id,
        estrellas: r.estrellas,
        comentario: r.comentario,
        respuesta: r.respuesta,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        lugar: { id: r.negocio.id, nombre: r.negocio.nombre, categoria: r.negocio.categoria, portada: r.negocio.portada },
      })),
    })
  } catch (err) {
    return fail(res, err)
  }
}

async function cambiarRespuesta(req: AuthedRequest, res: Response, respuesta: string | null) {
  const { id } = req.params
  if (!esUuid(id)) return res.status(400).json({ error: 'Reseña inválida' })
  try {
    const resultado = await responderResena(req.userId!, id, respuesta)
    if (resultado === 'no_encontrada') return res.status(404).json({ error: 'Reseña no encontrada' })
    if (resultado === 'prohibido') return res.status(403).json({ error: 'Solo el dueño del negocio puede responder' })
    return res.status(204).send()
  } catch (err) {
    return fail(res, err)
  }
}

export async function responder(req: AuthedRequest, res: Response) {
  const parsed = respuestaSchema.safeParse(req.body)
  if (!parsed.success) {
    return res.status(400).json({ error: 'Escribe una respuesta de máximo 1000 caracteres' })
  }
  return cambiarRespuesta(req, res, parsed.data.respuesta)
}

export async function quitarRespuesta(req: AuthedRequest, res: Response) {
  return cambiarRespuesta(req, res, null)
}

export async function listAdmin(_req: AuthedRequest, res: Response) {
  try {
    const resenas = await listResenasAdmin()
    return res.json({
      resenas: resenas.map((r) => ({
        id: r.id,
        estrellas: r.estrellas,
        comentario: r.comentario,
        respuesta: r.respuesta,
        createdAt: r.createdAt,
        autor: { nombre: nombrePublico(r.user.nombres, r.user.apellidos), email: r.user.email },
        lugar: { id: r.negocio.id, nombre: r.negocio.nombre },
      })),
    })
  } catch (err) {
    return fail(res, err)
  }
}

export async function borrarAdmin(req: AuthedRequest, res: Response) {
  const { id } = req.params
  if (!esUuid(id)) return res.status(400).json({ error: 'Reseña inválida' })
  try {
    const existia = await borrarResenaAdmin(id)
    if (!existia) return res.status(404).json({ error: 'Reseña no encontrada' })
    return res.status(204).send()
  } catch (err) {
    return fail(res, err)
  }
}
