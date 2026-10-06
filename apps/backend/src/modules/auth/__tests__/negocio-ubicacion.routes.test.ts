import { describe, it, expect, vi, beforeEach } from 'vitest'
import express from 'express'
import request from 'supertest'
import jwt from 'jsonwebtoken'

vi.mock('../../../config/prisma', () => ({
  prisma: {
    user: { findUnique: vi.fn(), findMany: vi.fn() },
    negocioProfile: { findUnique: vi.fn(), update: vi.fn(), create: vi.fn() },
    notification: { createMany: vi.fn() },
  },
}))

import { prisma } from '../../../config/prisma'
import { authRouter } from '../auth.routes'

const userFind = vi.mocked(prisma.user.findUnique)
const negocioFind = vi.mocked(prisma.negocioProfile.findUnique)
const negocioUpdate = vi.mocked(prisma.negocioProfile.update)
const negocioCreate = vi.mocked(prisma.negocioProfile.create)

const DUEÑO = 'dueno-1'
const NEGOCIO = '44444444-4444-4444-8444-444444444444'
const FIME = { latitud: 19.12492145230218, longitud: -104.40020700589847 }

function negocioRow(data: Record<string, unknown> = {}) {
  return {
    id: NEGOCIO,
    userId: DUEÑO,
    nombre: 'Mariscos El Faro',
    categoria: 'Restaurante',
    descripcion: null,
    direccion: 'Av. Audiencia 12',
    telefono: null,
    sitioWeb: null,
    horario: null,
    portada: null,
    galeria: [],
    archivo360: null,
    arMarcador: null,
    arGeo: null,
    latitud: null,
    longitud: null,
    estado: 'aprobado',
    createdAt: new Date('2026-10-05T00:00:00Z'),
    ...data,
  }
}

function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api/auth', authRouter)
  return app
}

const auth = () => `Bearer ${jwt.sign({ sub: DUEÑO }, process.env.JWT_SECRET!)}`

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(prisma.user.findMany).mockResolvedValue([])
})

describe('el dueño y las coordenadas de su negocio', () => {
  it('guarda el pin junto con la dirección y /me se lo regresa', async () => {
    const guardado = negocioRow({ ...FIME })
    userFind.mockResolvedValue({ id: DUEÑO, rol: 'negocio', activo: true, nombres: 'Ana', email: 'a@x.mx', negocios: [guardado] } as any)
    negocioFind.mockResolvedValue(negocioRow() as any)
    negocioUpdate.mockResolvedValue(guardado as any)

    const res = await request(buildApp())
      .patch(`/api/auth/profile/negocios/${NEGOCIO}`)
      .set('Authorization', auth())
      .send({ direccion: 'Av. Audiencia 12', ...FIME })

    expect(res.status).toBe(200)
    expect(negocioUpdate.mock.calls[0][0]).toMatchObject({ where: { id: NEGOCIO }, data: { direccion: 'Av. Audiencia 12', ...FIME } })
    expect(res.body.user.negocios[0]).toMatchObject(FIME)
  })

  it('no puede mover el pin de un negocio que no es suyo', async () => {
    userFind.mockResolvedValue({ id: DUEÑO, rol: 'negocio', activo: true, negocios: [] } as any)
    negocioFind.mockResolvedValue(negocioRow({ userId: 'otro' }) as any)

    const res = await request(buildApp()).patch(`/api/auth/profile/negocios/${NEGOCIO}`).set('Authorization', auth()).send(FIME)

    expect(res.status).toBe(404)
    expect(negocioUpdate).not.toHaveBeenCalled()
  })

  it('pide latitud y longitud juntas', async () => {
    userFind.mockResolvedValue({ id: DUEÑO, rol: 'negocio', activo: true, negocios: [] } as any)

    const res = await request(buildApp())
      .patch(`/api/auth/profile/negocios/${NEGOCIO}`)
      .set('Authorization', auth())
      .send({ latitud: 19.12 })

    expect(res.status).toBe(400)
  })

  it('al sugerir un negocio nuevo puede mandar su pin', async () => {
    userFind.mockResolvedValue({
      id: DUEÑO,
      rol: 'negocio',
      activo: true,
      nombres: 'Ana',
      email: 'a@x.mx',
      negocios: [negocioRow()],
    } as any)
    negocioCreate.mockImplementation(({ data }: any) => Promise.resolve(negocioRow({ ...data, estado: 'pendiente' })) as any)

    const res = await request(buildApp())
      .post('/api/auth/profile/negocios')
      .set('Authorization', auth())
      .send({ nombre: 'Mariscos El Faro 2', direccion: 'Blvd. Miguel de la Madrid', ...FIME })

    expect(res.status).toBe(201)
    expect(negocioCreate.mock.calls[0][0].data).toMatchObject({ nombre: 'Mariscos El Faro 2', ...FIME })
  })
})
