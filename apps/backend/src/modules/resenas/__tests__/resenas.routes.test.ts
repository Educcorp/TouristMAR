import { describe, it, expect, vi, beforeEach } from 'vitest'
import express from 'express'
import request from 'supertest'
import jwt from 'jsonwebtoken'

vi.mock('../../../config/prisma', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    negocioProfile: { findFirst: vi.fn() },
    resena: {
      findMany: vi.fn(),
      findUnique: vi.fn(),
      groupBy: vi.fn(),
      upsert: vi.fn(),
      update: vi.fn(),
      deleteMany: vi.fn(),
    },
  },
}))

import { prisma } from '../../../config/prisma'
import { resenasRouter, resenasAdminRouter } from '../resenas.routes'

const userFind = vi.mocked(prisma.user.findUnique)
const negocioFindFirst = vi.mocked(prisma.negocioProfile.findFirst)
const resenaFindMany = vi.mocked(prisma.resena.findMany)
const resenaFindUnique = vi.mocked(prisma.resena.findUnique)
const resenaGroupBy = vi.mocked(prisma.resena.groupBy)
const resenaUpsert = vi.mocked(prisma.resena.upsert)
const resenaUpdate = vi.mocked(prisma.resena.update)
const resenaDeleteMany = vi.mocked(prisma.resena.deleteMany)

const VISITANTE = 'visitante-1'
const DUENO = 'dueno-1'
const ADMIN = 'admin-1'
const NEGOCIO = '44444444-4444-4444-8444-444444444444'
const RESENA = '66666666-6666-4666-8666-666666666666'

function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api/resenas', resenasRouter)
  app.use('/api/admin/resenas', resenasAdminRouter)
  return app
}

const token = (sub: string) => `Bearer ${jwt.sign({ sub }, process.env.JWT_SECRET!)}`

beforeEach(() => {
  vi.clearAllMocks()
  userFind.mockImplementation(({ where }: any) => {
    const rol = where.id === ADMIN ? 'admin' : where.id === DUENO ? 'negocio' : 'turista'
    return Promise.resolve({ id: where.id, rol, activo: true, negocios: [] }) as any
  })
})

describe('GET /api/resenas/lugar/:negocioId (público)', () => {
  it('devuelve el resumen, marca la reseña propia y solo expone el nombre con la inicial del apellido', async () => {
    resenaGroupBy.mockResolvedValue([
      { estrellas: 5, _count: { _all: 2 } },
      { estrellas: 3, _count: { _all: 1 } },
    ] as any)
    resenaFindMany.mockResolvedValue([
      {
        id: RESENA,
        userId: VISITANTE,
        estrellas: 5,
        comentario: 'Excelente',
        respuesta: null,
        respuestaEn: null,
        createdAt: new Date('2026-10-06T00:00:00Z'),
        user: { nombres: 'Carlos', apellidos: 'Mendoza', avatarUrl: null },
      },
      {
        id: 'otra',
        userId: 'alguien-mas',
        estrellas: 3,
        comentario: null,
        respuesta: null,
        respuestaEn: null,
        createdAt: new Date('2026-10-05T00:00:00Z'),
        user: { nombres: 'Laura', apellidos: null, avatarUrl: null },
      },
    ] as any)

    const res = await request(buildApp()).get(`/api/resenas/lugar/${NEGOCIO}`).set('Authorization', token(VISITANTE))

    expect(res.status).toBe(200)
    expect(res.body.resumen).toEqual({ promedio: 4.3, total: 3, porEstrellas: [0, 0, 1, 0, 2] })
    expect(res.body.resenas[0]).toMatchObject({ autor: { nombre: 'Carlos M.' }, mia: true })
    expect(res.body.resenas[1]).toMatchObject({ autor: { nombre: 'Laura' }, mia: false })
    expect(JSON.stringify(res.body)).not.toContain('Mendoza')
  })

  it('un id que no es UUID responde 400', async () => {
    const res = await request(buildApp()).get('/api/resenas/lugar/demo-audiencia')
    expect(res.status).toBe(400)
  })
})

describe('PUT /api/resenas/lugar/:negocioId', () => {
  const put = (body: unknown, who = VISITANTE) =>
    request(buildApp()).put(`/api/resenas/lugar/${NEGOCIO}`).set('Authorization', token(who)).send(body as object)

  it('sin sesión responde 401', async () => {
    const res = await request(buildApp()).put(`/api/resenas/lugar/${NEGOCIO}`).send({ estrellas: 5 })
    expect(res.status).toBe(401)
  })

  it('crea o edita (una por usuario y lugar) con estrellas y comentario recortado', async () => {
    negocioFindFirst.mockResolvedValue({ userId: DUENO } as any)

    const res = await put({ estrellas: 4, comentario: '  Muy bonito  ' })

    expect(res.status).toBe(204)
    expect(resenaUpsert.mock.calls[0][0]).toMatchObject({
      where: { userId_negocioId: { userId: VISITANTE, negocioId: NEGOCIO } },
      create: { userId: VISITANTE, negocioId: NEGOCIO, estrellas: 4, comentario: 'Muy bonito' },
      update: { estrellas: 4, comentario: 'Muy bonito' },
    })
  })

  it('el comentario es opcional', async () => {
    negocioFindFirst.mockResolvedValue({ userId: DUENO } as any)
    const res = await put({ estrellas: 5, comentario: '   ' })
    expect(res.status).toBe(204)
    expect(resenaUpsert.mock.calls[0][0]).toMatchObject({ create: { comentario: null } })
  })

  it.each([0, 6, 2.5, 'abc', null])('rechaza estrellas inválidas (%s)', async (estrellas) => {
    const res = await put({ estrellas })
    expect(res.status).toBe(400)
    expect(resenaUpsert).not.toHaveBeenCalled()
  })

  it('rechaza un comentario de más de 1000 caracteres', async () => {
    const res = await put({ estrellas: 5, comentario: 'x'.repeat(1001) })
    expect(res.status).toBe(400)
    expect(resenaUpsert).not.toHaveBeenCalled()
  })

  it('un lugar que no existe o no está aprobado responde 404', async () => {
    negocioFindFirst.mockResolvedValue(null)
    const res = await put({ estrellas: 5 })
    expect(res.status).toBe(404)
    expect(resenaUpsert).not.toHaveBeenCalled()
  })

  it('el dueño no puede reseñar su propio negocio', async () => {
    negocioFindFirst.mockResolvedValue({ userId: DUENO } as any)
    const res = await put({ estrellas: 5 }, DUENO)
    expect(res.status).toBe(403)
    expect(resenaUpsert).not.toHaveBeenCalled()
  })
})

describe('DELETE /api/resenas/lugar/:negocioId', () => {
  it('borra solo la reseña del propio usuario', async () => {
    resenaDeleteMany.mockResolvedValue({ count: 1 } as any)
    const res = await request(buildApp()).delete(`/api/resenas/lugar/${NEGOCIO}`).set('Authorization', token(VISITANTE))
    expect(res.status).toBe(204)
    expect(resenaDeleteMany.mock.calls[0][0]).toEqual({ where: { userId: VISITANTE, negocioId: NEGOCIO } })
  })
})

describe('respuesta del negocio', () => {
  const ruta = `/api/resenas/${RESENA}/respuesta`

  it('el dueño del negocio reseñado puede responder', async () => {
    resenaFindUnique.mockResolvedValue({ negocio: { userId: DUENO } } as any)
    const res = await request(buildApp()).put(ruta).set('Authorization', token(DUENO)).send({ respuesta: 'Gracias por venir' })
    expect(res.status).toBe(204)
    expect(resenaUpdate.mock.calls[0][0]).toMatchObject({ where: { id: RESENA }, data: { respuesta: 'Gracias por venir' } })
  })

  it('otro usuario no puede responder', async () => {
    resenaFindUnique.mockResolvedValue({ negocio: { userId: DUENO } } as any)
    const res = await request(buildApp()).put(ruta).set('Authorization', token(VISITANTE)).send({ respuesta: 'Hola' })
    expect(res.status).toBe(403)
    expect(resenaUpdate).not.toHaveBeenCalled()
  })

  it('una respuesta vacía se rechaza', async () => {
    const res = await request(buildApp()).put(ruta).set('Authorization', token(DUENO)).send({ respuesta: '   ' })
    expect(res.status).toBe(400)
  })

  it('el dueño puede quitar su respuesta', async () => {
    resenaFindUnique.mockResolvedValue({ negocio: { userId: DUENO } } as any)
    const res = await request(buildApp()).delete(ruta).set('Authorization', token(DUENO))
    expect(res.status).toBe(204)
    expect(resenaUpdate.mock.calls[0][0]).toMatchObject({ data: { respuesta: null, respuestaEn: null } })
  })

  it('una reseña inexistente responde 404', async () => {
    resenaFindUnique.mockResolvedValue(null)
    const res = await request(buildApp()).put(ruta).set('Authorization', token(DUENO)).send({ respuesta: 'Hola' })
    expect(res.status).toBe(404)
  })
})

describe('moderación del admin', () => {
  it('un admin elimina cualquier reseña', async () => {
    resenaDeleteMany.mockResolvedValue({ count: 1 } as any)
    const res = await request(buildApp()).delete(`/api/admin/resenas/${RESENA}`).set('Authorization', token(ADMIN))
    expect(res.status).toBe(204)
    expect(resenaDeleteMany.mock.calls[0][0]).toEqual({ where: { id: RESENA } })
  })

  it('un visitante no puede usar el panel de moderación', async () => {
    const res = await request(buildApp()).delete(`/api/admin/resenas/${RESENA}`).set('Authorization', token(VISITANTE))
    expect(res.status).toBe(403)
    expect(resenaDeleteMany).not.toHaveBeenCalled()
  })

  it('eliminar una reseña que ya no existe responde 404', async () => {
    resenaDeleteMany.mockResolvedValue({ count: 0 } as any)
    const res = await request(buildApp()).delete(`/api/admin/resenas/${RESENA}`).set('Authorization', token(ADMIN))
    expect(res.status).toBe(404)
  })
})
