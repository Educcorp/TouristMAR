import { describe, it, expect, vi, beforeEach } from 'vitest'
import express from 'express'
import request from 'supertest'
import jwt from 'jsonwebtoken'

vi.mock('../../../config/prisma', () => ({
  prisma: {
    user: { findUnique: vi.fn(), findMany: vi.fn() },
    negocioProfile: { findUnique: vi.fn() },
    recorrido360: { count: vi.fn(), create: vi.fn(), findFirst: vi.fn() },
    solicitudRecorrido360: { findFirst: vi.fn(), findMany: vi.fn(), findUnique: vi.fn(), create: vi.fn(), update: vi.fn() },
    notification: { create: vi.fn(), createMany: vi.fn() },
  },
}))

import { prisma } from '../../../config/prisma'
import { authRouter } from '../../auth/auth.routes'
import { recorridosAdminRouter } from '../recorridos.routes'

const userFind = vi.mocked(prisma.user.findUnique)
const negocioFind = vi.mocked(prisma.negocioProfile.findUnique)
const recorridoCount = vi.mocked(prisma.recorrido360.count)
const solicitudFindFirst = vi.mocked(prisma.solicitudRecorrido360.findFirst)
const solicitudFindUnique = vi.mocked(prisma.solicitudRecorrido360.findUnique)
const solicitudCreate = vi.mocked(prisma.solicitudRecorrido360.create)
const solicitudUpdate = vi.mocked(prisma.solicitudRecorrido360.update)
const notificar = vi.mocked(prisma.notification.create)
const notificarAdmins = vi.mocked(prisma.notification.createMany)

const DUEÑO = 'dueno-1'
const ADMIN = 'admin-1'
const NEGOCIO = '44444444-4444-4444-8444-444444444444'
const SOLICITUD = '55555555-5555-4555-8555-555555555555'
const FIME = { latitud: 19.12492145230218, longitud: -104.40020700589847 }

const negocioRow = (data: Record<string, unknown> = {}) => ({
  id: NEGOCIO,
  userId: DUEÑO,
  nombre: 'Mariscos El Faro',
  latitud: null,
  longitud: null,
  ...data,
})

const solicitudRow = (data: Record<string, unknown> = {}) => ({
  id: SOLICITUD,
  negocioId: NEGOCIO,
  mensaje: '',
  estado: 'pendiente',
  nota: '',
  atendidaPor: null,
  atendidaEn: null,
  createdAt: new Date('2026-10-07T00:00:00Z'),
  negocio: {
    id: NEGOCIO,
    nombre: 'Mariscos El Faro',
    categoria: 'Restaurante',
    direccion: 'Av. Audiencia 12',
    telefono: null,
    ...FIME,
    user: { nombres: 'Ana', apellidos: 'López', email: 'ana@faro.mx' },
  },
  ...data,
})

function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api/auth', authRouter)
  app.use('/api/admin/recorridos', recorridosAdminRouter)
  return app
}

const token = (sub: string) => `Bearer ${jwt.sign({ sub }, process.env.JWT_SECRET!)}`
const rutaNegocio = `/api/auth/profile/negocios/${NEGOCIO}/recorrido-360`

beforeEach(() => {
  vi.clearAllMocks()
  userFind.mockImplementation(({ where }: any) =>
    Promise.resolve(
      where.id === ADMIN
        ? { id: ADMIN, rol: 'admin', activo: true }
        : { id: DUEÑO, rol: 'negocio', activo: true, negocios: [] },
    ) as any,
  )
  vi.mocked(prisma.user.findMany).mockResolvedValue([{ id: ADMIN }] as any)
  recorridoCount.mockResolvedValue(0)
  solicitudFindFirst.mockResolvedValue(null)
})

describe('el negocio solicita su recorrido 360°', () => {
  it('con su pin guardado, crea la solicitud y avisa a los admins', async () => {
    negocioFind.mockResolvedValue(negocioRow(FIME) as any)
    solicitudCreate.mockResolvedValue(solicitudRow({ mensaje: 'Mejor por las mañanas' }) as any)

    const res = await request(buildApp())
      .post(`${rutaNegocio}/solicitud`)
      .set('Authorization', token(DUEÑO))
      .send({ mensaje: 'Mejor por las mañanas' })

    expect(res.status).toBe(201)
    expect(solicitudCreate.mock.calls[0][0]).toMatchObject({ data: { negocioId: NEGOCIO, mensaje: 'Mejor por las mañanas' } })
    expect(res.body.solicitud).toMatchObject({ estado: 'pendiente', negocioId: NEGOCIO })
    expect(notificarAdmins.mock.calls[0][0]).toMatchObject({
      data: [{ userId: ADMIN, tipo: 'recorrido_solicitado', negocioId: NEGOCIO }],
    })
  })

  it('sin pin en el mapa no puede solicitarlo', async () => {
    negocioFind.mockResolvedValue(negocioRow() as any)

    const res = await request(buildApp()).post(`${rutaNegocio}/solicitud`).set('Authorization', token(DUEÑO)).send({})

    expect(res.status).toBe(400)
    expect(res.body.error).toMatch(/mapa/)
    expect(solicitudCreate).not.toHaveBeenCalled()
  })

  it('si ya tiene recorrido no puede volver a pedirlo', async () => {
    negocioFind.mockResolvedValue(negocioRow(FIME) as any)
    recorridoCount.mockResolvedValue(1)

    const res = await request(buildApp()).post(`${rutaNegocio}/solicitud`).set('Authorization', token(DUEÑO)).send({})

    expect(res.status).toBe(409)
    expect(solicitudCreate).not.toHaveBeenCalled()
  })

  it('no duplica una solicitud pendiente', async () => {
    negocioFind.mockResolvedValue(negocioRow(FIME) as any)
    solicitudFindFirst.mockResolvedValue(solicitudRow() as any)

    const res = await request(buildApp()).post(`${rutaNegocio}/solicitud`).set('Authorization', token(DUEÑO)).send({})

    expect(res.status).toBe(409)
    expect(solicitudCreate).not.toHaveBeenCalled()
  })

  it('no puede solicitarlo para un negocio ajeno', async () => {
    negocioFind.mockResolvedValue(negocioRow({ ...FIME, userId: 'otro' }) as any)

    const res = await request(buildApp()).post(`${rutaNegocio}/solicitud`).set('Authorization', token(DUEÑO)).send({})

    expect(res.status).toBe(404)
  })

  it('consulta si ya tiene recorrido y su última solicitud', async () => {
    negocioFind.mockResolvedValue(negocioRow(FIME) as any)
    solicitudFindFirst.mockResolvedValue(solicitudRow() as any)

    const res = await request(buildApp()).get(rutaNegocio).set('Authorization', token(DUEÑO))

    expect(res.status).toBe(200)
    expect(res.body).toMatchObject({ tieneRecorrido: false, solicitud: { id: SOLICITUD, estado: 'pendiente' } })
  })
})

describe('el admin atiende las solicitudes', () => {
  it('un negocio no puede ver la lista del admin', async () => {
    const res = await request(buildApp()).get('/api/admin/recorridos/solicitudes').set('Authorization', token(DUEÑO))
    expect(res.status).toBe(403)
  })

  it('lista las solicitudes con los datos del negocio', async () => {
    vi.mocked(prisma.solicitudRecorrido360.findMany).mockResolvedValue([solicitudRow()] as any)

    const res = await request(buildApp())
      .get('/api/admin/recorridos/solicitudes?estado=pendiente')
      .set('Authorization', token(ADMIN))

    expect(res.status).toBe(200)
    expect(vi.mocked(prisma.solicitudRecorrido360.findMany).mock.calls[0][0]).toMatchObject({ where: { estado: 'pendiente' } })
    expect(res.body.solicitudes[0].negocio).toMatchObject({ nombre: 'Mariscos El Faro', contacto: 'Ana López', email: 'ana@faro.mx', ...FIME })
  })

  it('al rechazarla le avisa al negocio con la nota', async () => {
    solicitudFindUnique.mockResolvedValue(solicitudRow() as any)
    solicitudUpdate.mockResolvedValue(solicitudRow({ estado: 'rechazada', nota: 'Fuera de cobertura' }) as any)
    negocioFind.mockResolvedValue(negocioRow() as any)

    const res = await request(buildApp())
      .patch(`/api/admin/recorridos/solicitudes/${SOLICITUD}`)
      .set('Authorization', token(ADMIN))
      .send({ estado: 'rechazada', nota: 'Fuera de cobertura' })

    expect(res.status).toBe(200)
    expect(solicitudUpdate.mock.calls[0][0]).toMatchObject({ data: { estado: 'rechazada', nota: 'Fuera de cobertura', atendidaPor: ADMIN } })
    expect(notificar.mock.calls[0][0]).toMatchObject({ data: { userId: DUEÑO, tipo: 'recorrido_rechazado' } })
  })

  it('no se puede atender dos veces', async () => {
    solicitudFindUnique.mockResolvedValue(solicitudRow({ estado: 'completada' }) as any)

    const res = await request(buildApp())
      .patch(`/api/admin/recorridos/solicitudes/${SOLICITUD}`)
      .set('Authorization', token(ADMIN))
      .send({ estado: 'rechazada' })

    expect(res.status).toBe(409)
    expect(solicitudUpdate).not.toHaveBeenCalled()
  })

  it('al crear el recorrido del negocio, su solicitud pendiente queda completada', async () => {
    negocioFind.mockResolvedValue(negocioRow() as any)
    vi.mocked(prisma.recorrido360.findFirst).mockResolvedValue(null)
    vi.mocked(prisma.recorrido360.create).mockResolvedValue({
      id: '66666666-6666-4666-8666-666666666666',
      negocioId: NEGOCIO,
      nombre: 'faro_360',
      titulo: 'Mariscos El Faro',
      texto: '',
      latitud: null,
      longitud: null,
      activo: true,
      negocio: { nombre: 'Mariscos El Faro' },
      escenas: [],
    } as any)
    vi.mocked(prisma.solicitudRecorrido360.findMany).mockResolvedValue([{ id: SOLICITUD }] as any)
    solicitudFindUnique.mockResolvedValue(solicitudRow() as any)
    solicitudUpdate.mockResolvedValue(solicitudRow({ estado: 'completada' }) as any)

    const res = await request(buildApp())
      .post('/api/admin/recorridos')
      .set('Authorization', token(ADMIN))
      .send({ nombre: 'faro_360', titulo: 'Mariscos El Faro', texto: 'Recorrido del restaurante', negocioId: NEGOCIO })

    expect(res.status).toBe(201)
    expect(solicitudUpdate.mock.calls[0][0]).toMatchObject({ where: { id: SOLICITUD }, data: { estado: 'completada' } })
    expect(notificar.mock.calls[0][0]).toMatchObject({ data: { userId: DUEÑO, tipo: 'recorrido_listo' } })
  })
})
