import { describe, it, expect, vi, beforeEach } from 'vitest'
import express from 'express'
import request from 'supertest'
import jwt from 'jsonwebtoken'

vi.mock('../../../config/prisma', () => ({
  prisma: {
    user: { findUnique: vi.fn(), findFirst: vi.fn() },
    negocioProfile: { findUnique: vi.fn(), update: vi.fn(), create: vi.fn(), delete: vi.fn() },
  },
}))

import { prisma } from '../../../config/prisma'
import { adminRouter } from '../admin.routes'

const userFind = vi.mocked(prisma.user.findUnique)
const negocioFind = vi.mocked(prisma.negocioProfile.findUnique)
const negocioUpdate = vi.mocked(prisma.negocioProfile.update)
const negocioCreate = vi.mocked(prisma.negocioProfile.create)
const userFindFirst = vi.mocked(prisma.user.findFirst)

function lugarRow(data: Record<string, unknown>) {
  return {
    id: NEGOCIO_ID,
    userId: 'super-1',
    categoria: null,
    descripcion: null,
    direccion: null,
    estado: 'aprobado',
    latitud: null,
    longitud: null,
    createdAt: new Date('2026-10-05T00:00:00Z'),
    user: { email: 'super@touristmar.mx', nombres: 'Super' },
    ...data,
  }
}

const NEGOCIO_ID = '44444444-4444-4444-8444-444444444444'
const url = `/api/admin/negocios/${NEGOCIO_ID}/ubicacion`

function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api/admin', adminRouter)
  return app
}

function como(rol: string) {
  userFind.mockResolvedValue({ id: 'u-1', rol, activo: true, negocios: [] } as any)
  return `Bearer ${jwt.sign({ sub: 'u-1' }, process.env.JWT_SECRET!)}`
}

beforeEach(() => {
  vi.clearAllMocks()
  negocioFind.mockResolvedValue({ id: NEGOCIO_ID } as any)
  negocioUpdate.mockImplementation(({ data }: any) => Promise.resolve({ id: NEGOCIO_ID, ...data }) as any)
})

describe('PUT /api/admin/negocios/:id/ubicacion', () => {
  it('un admin fija el pin del lugar en el mapa', async () => {
    const res = await request(buildApp())
      .put(url)
      .set('Authorization', como('admin'))
      .send({ ubicacion: { latitud: 19.0675, longitud: -104.303 } })

    expect(res.status).toBe(200)
    expect(negocioUpdate).toHaveBeenCalledWith({ where: { id: NEGOCIO_ID }, data: { latitud: 19.0675, longitud: -104.303 } })
    expect(res.body.negocio).toEqual({ id: NEGOCIO_ID, latitud: 19.0675, longitud: -104.303 })
  })

  it('null quita el pin', async () => {
    const res = await request(buildApp()).put(url).set('Authorization', como('admin')).send({ ubicacion: null })

    expect(res.status).toBe(200)
    expect(negocioUpdate.mock.calls[0][0].data).toEqual({ latitud: null, longitud: null })
  })

  it('rechaza coordenadas fuera de rango', async () => {
    const res = await request(buildApp())
      .put(url)
      .set('Authorization', como('admin'))
      .send({ ubicacion: { latitud: 120, longitud: -104.3 } })

    expect(res.status).toBe(400)
    expect(negocioUpdate).not.toHaveBeenCalled()
  })

  it('404 si el negocio no existe', async () => {
    negocioFind.mockResolvedValue(null)

    const res = await request(buildApp())
      .put(url)
      .set('Authorization', como('admin'))
      .send({ ubicacion: { latitud: 19, longitud: -104 } })

    expect(res.status).toBe(404)
  })

  it('un dueño de negocio no puede usarlo', async () => {
    const res = await request(buildApp())
      .put(url)
      .set('Authorization', como('negocio'))
      .send({ ubicacion: { latitud: 19, longitud: -104 } })

    expect(res.status).toBe(403)
  })
})

describe('POST /api/admin/lugares', () => {
  const fime = {
    nombre: 'Facultad de Ingeniería Electromecánica (FIME)',
    categoria: 'Cultura y educación',
    direccion: 'Universidad de Colima, Campus El Naranjo, Manzanillo, Col.',
    latitud: 19.12492145230218,
    longitud: -104.40020700589847,
  }

  it('crea el lugar ya aprobado, a nombre del super admin y con su pin', async () => {
    userFindFirst.mockResolvedValue({ id: 'super-1' } as any)
    negocioCreate.mockImplementation(({ data }: any) => Promise.resolve(lugarRow(data)) as any)

    const res = await request(buildApp()).post('/api/admin/lugares').set('Authorization', como('admin')).send(fime)

    expect(res.status).toBe(201)
    expect(userFindFirst.mock.calls[0][0]).toMatchObject({ where: { rol: 'super_admin' } })
    expect(negocioCreate.mock.calls[0][0].data).toMatchObject({ ...fime, userId: 'super-1', estado: 'aprobado' })
    expect(res.body.negocio).toMatchObject({ nombre: fime.nombre, latitud: fime.latitud, longitud: fime.longitud, estado: 'aprobado' })
  })

  it('pide latitud y longitud juntas', async () => {
    const res = await request(buildApp())
      .post('/api/admin/lugares')
      .set('Authorization', como('admin'))
      .send({ nombre: 'Mirador', latitud: 19.1 })

    expect(res.status).toBe(400)
    expect(negocioCreate).not.toHaveBeenCalled()
  })

  it('un turista no puede crear lugares', async () => {
    const res = await request(buildApp()).post('/api/admin/lugares').set('Authorization', como('turista')).send(fime)
    expect(res.status).toBe(403)
  })
})

describe('PATCH /api/admin/negocios/:id', () => {
  it('el admin corrige dirección y pin de cualquier lugar', async () => {
    negocioUpdate.mockImplementation(({ data }: any) => Promise.resolve(lugarRow({ nombre: 'Playa', ...data })) as any)

    const res = await request(buildApp())
      .patch(`/api/admin/negocios/${NEGOCIO_ID}`)
      .set('Authorization', como('admin'))
      .send({ direccion: 'Av. Audiencia s/n', latitud: 19.12, longitud: -104.4 })

    expect(res.status).toBe(200)
    expect(negocioUpdate.mock.calls[0][0]).toMatchObject({
      where: { id: NEGOCIO_ID },
      data: { direccion: 'Av. Audiencia s/n', latitud: 19.12, longitud: -104.4 },
    })
    expect(res.body.negocio.direccion).toBe('Av. Audiencia s/n')
  })

  it('404 si el lugar no existe', async () => {
    negocioFind.mockResolvedValue(null)
    const res = await request(buildApp())
      .patch(`/api/admin/negocios/${NEGOCIO_ID}`)
      .set('Authorization', como('admin'))
      .send({ direccion: 'x' })
    expect(res.status).toBe(404)
  })
})

describe('DELETE /api/admin/negocios/:id', () => {
  it('borra el lugar (sin recorridos ni marcadores)', async () => {
    negocioFind.mockResolvedValue({ id: NEGOCIO_ID, recorridos360: [], arMarcadores: [] } as any)
    const negocioDelete = vi.mocked(prisma.negocioProfile.delete)

    const res = await request(buildApp()).delete(`/api/admin/negocios/${NEGOCIO_ID}`).set('Authorization', como('admin'))

    expect(res.status).toBe(204)
    expect(negocioDelete).toHaveBeenCalledWith({ where: { id: NEGOCIO_ID } })
  })

  it('404 si el lugar no existe', async () => {
    negocioFind.mockResolvedValue(null)

    const res = await request(buildApp()).delete(`/api/admin/negocios/${NEGOCIO_ID}`).set('Authorization', como('admin'))

    expect(res.status).toBe(404)
  })

  it('un dueño de negocio no puede borrar lugares', async () => {
    const res = await request(buildApp()).delete(`/api/admin/negocios/${NEGOCIO_ID}`).set('Authorization', como('negocio'))
    expect(res.status).toBe(403)
  })
})
