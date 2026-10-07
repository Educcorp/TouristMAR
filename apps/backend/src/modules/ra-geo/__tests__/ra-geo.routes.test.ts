import { describe, it, expect, vi, beforeEach } from 'vitest'
import express from 'express'
import request from 'supertest'
import jwt from 'jsonwebtoken'

vi.mock('../../../config/prisma', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    negocioProfile: { findUnique: vi.fn() },
    puntoRaGeo: { findMany: vi.fn(), findUnique: vi.fn(), count: vi.fn(), create: vi.fn(), update: vi.fn(), deleteMany: vi.fn() },
  },
}))

import { prisma } from '../../../config/prisma'
import { raGeoAdminRouter } from '../ra-geo.routes'

const ADMIN = 'admin-1'
const FIME = 'f24442e4-6613-4427-99df-a7f962d6b99e'
const PUNTO = '77777777-7777-4777-8777-777777777777'

const punto = (data: Record<string, unknown> = {}) => ({
  id: PUNTO,
  negocioId: FIME,
  titulo: 'Entrada principal',
  resumen: '',
  detalle: '',
  imagenUrl: '',
  audioUrl: '',
  latitud: 19.1239,
  longitud: -104.4001,
  radioVisible: 100,
  radioCercano: 10,
  orden: 0,
  activo: true,
  ...data,
})

function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api/admin/ra-geo', raGeoAdminRouter)
  return app
}

const como = (rol: string) => {
  vi.mocked(prisma.user.findUnique).mockResolvedValue({ id: ADMIN, rol, activo: true } as any)
  return `Bearer ${jwt.sign({ sub: ADMIN }, process.env.JWT_SECRET!)}`
}

beforeEach(() => vi.clearAllMocks())

describe('puntos de la RA por geolocalización (admin)', () => {
  it('un turista no puede darlos de alta', async () => {
    const res = await request(buildApp())
      .post(`/api/admin/ra-geo/lugares/${FIME}/puntos`)
      .set('Authorization', como('turista'))
      .send({ titulo: 'x', latitud: 19, longitud: -104 })
    expect(res.status).toBe(403)
  })

  it('crea un punto con los radios por defecto y al final de la lista', async () => {
    vi.mocked(prisma.negocioProfile.findUnique).mockResolvedValue({ id: FIME } as any)
    vi.mocked(prisma.puntoRaGeo.count).mockResolvedValue(2)
    vi.mocked(prisma.puntoRaGeo.create).mockImplementation(({ data }: any) => Promise.resolve(punto(data)) as any)

    const res = await request(buildApp())
      .post(`/api/admin/ra-geo/lugares/${FIME}/puntos`)
      .set('Authorization', como('admin'))
      .send({ titulo: 'Entrada principal', resumen: 'Acceso por la carretera', latitud: 19.1239, longitud: -104.4001 })

    expect(res.status).toBe(201)
    expect(vi.mocked(prisma.puntoRaGeo.create).mock.calls[0][0].data).toMatchObject({ negocioId: FIME, orden: 2 })
    expect(res.body.punto).toMatchObject({ titulo: 'Entrada principal', radioVisible: 100, radioCercano: 10 })
  })

  it('el radio cercano tiene que ser menor que el visible', async () => {
    const res = await request(buildApp())
      .post(`/api/admin/ra-geo/lugares/${FIME}/puntos`)
      .set('Authorization', como('admin'))
      .send({ titulo: 'x', latitud: 19, longitud: -104, radioVisible: 20, radioCercano: 30 })
    expect(res.status).toBe(400)
    expect(prisma.puntoRaGeo.create).not.toHaveBeenCalled()
  })

  it('rechaza coordenadas fuera de rango', async () => {
    const res = await request(buildApp())
      .post(`/api/admin/ra-geo/lugares/${FIME}/puntos`)
      .set('Authorization', como('admin'))
      .send({ titulo: 'x', latitud: 120, longitud: -104 })
    expect(res.status).toBe(400)
  })

  it('al editar solo un radio lo compara con el que ya estaba guardado', async () => {
    vi.mocked(prisma.puntoRaGeo.findUnique).mockResolvedValue(punto({ radioVisible: 50 }) as any)

    const res = await request(buildApp())
      .patch(`/api/admin/ra-geo/puntos/${PUNTO}`)
      .set('Authorization', como('admin'))
      .send({ radioCercano: 60 })

    expect(res.status).toBe(400)
    expect(prisma.puntoRaGeo.update).not.toHaveBeenCalled()
  })

  it('edita y borra un punto', async () => {
    vi.mocked(prisma.puntoRaGeo.findUnique).mockResolvedValue(punto() as any)
    vi.mocked(prisma.puntoRaGeo.update).mockResolvedValue(punto({ activo: false }) as any)
    vi.mocked(prisma.puntoRaGeo.deleteMany).mockResolvedValue({ count: 1 })

    const editado = await request(buildApp())
      .patch(`/api/admin/ra-geo/puntos/${PUNTO}`)
      .set('Authorization', como('admin'))
      .send({ activo: false })
    const borrado = await request(buildApp()).delete(`/api/admin/ra-geo/puntos/${PUNTO}`).set('Authorization', como('admin'))

    expect(editado.body.punto.activo).toBe(false)
    expect(borrado.status).toBe(204)
  })
})
