import { describe, it, expect, vi, beforeEach } from 'vitest'
import express from 'express'
import request from 'supertest'
import jwt from 'jsonwebtoken'

// Flujo "empresa solicita un negocio nuevo → el admin lo revisa": la
// solicitud lleva ubicación/contacto, el admin recibe la notificación y desde
// el panel puede ver el detalle, editarlo y cambiar la portada.

vi.mock('../../../config/prisma', () => ({
  prisma: {
    user: { findUnique: vi.fn(), findMany: vi.fn() },
    negocioProfile: { findUnique: vi.fn(), findMany: vi.fn(), create: vi.fn(), update: vi.fn() },
    notification: { createMany: vi.fn(), create: vi.fn() },
  },
}))

const storageBucket = {
  upload: vi.fn(),
  getPublicUrl: vi.fn(),
}

vi.mock('../../../config/supabase', () => ({
  AVATARS_BUCKET: 'avatars',
  NEGOCIO_ASSETS_BUCKET: 'negocio-assets',
  AR_MARCADORES_BUCKET: 'ar-marcadores',
  RECORRIDOS_360_BUCKET: 'recorridos-360',
  supabase: { storage: { from: () => storageBucket } },
}))

const { notifyAdmins } = vi.hoisted(() => ({ notifyAdmins: vi.fn() }))
vi.mock('../../notifications/notification.service', () => ({
  notifyAdmins,
  notifyUser: vi.fn(),
}))

import { prisma } from '../../../config/prisma'
import { adminRouter } from '../admin.routes'
import { authRouter } from '../../auth/auth.routes'

const userFind = vi.mocked(prisma.user.findUnique)
const negocioFind = vi.mocked(prisma.negocioProfile.findUnique)
const negocioCreate = vi.mocked(prisma.negocioProfile.create)
const negocioUpdate = vi.mocked(prisma.negocioProfile.update)
const negocioFindMany = vi.mocked(prisma.negocioProfile.findMany)

const NEGOCIO_ID = '22222222-2222-4222-8222-222222222222'

function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api/auth', authRouter)
  app.use('/api/admin', adminRouter)
  return app
}

function tokenFor(id: string) {
  return jwt.sign({ sub: id }, process.env.JWT_SECRET!)
}

function detalleRow(overrides: Record<string, unknown> = {}) {
  return {
    id: NEGOCIO_ID,
    userId: 'empresa-1',
    nombre: 'Mariscos La Bahía',
    categoria: 'Restaurantes',
    descripcion: null,
    direccion: 'Malecón 12',
    telefono: '314 000 0000',
    sitioWeb: null,
    horario: null,
    portada: null,
    galeria: [],
    latitud: 19.05,
    longitud: -104.31,
    estado: 'pendiente',
    createdAt: new Date('2026-10-01T00:00:00Z'),
    user: { id: 'empresa-1', email: 'cafe@correo.com', nombres: 'Ana', createdAt: new Date('2026-09-01T00:00:00Z') },
    arMarcadores: [{ id: 'm-1', nombre: 'menu_bahia', titulo: 'Menú', activo: true }],
    recorridos360: [],
    ...overrides,
  }
}

const comoAdmin = () => userFind.mockResolvedValue({ id: 'admin-1', rol: 'admin', activo: true, negocios: [] } as any)

describe('Solicitud de negocio nuevo (empresa → admin)', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('la empresa manda ubicación, teléfono y horario, y se notifica a los admins', async () => {
    userFind.mockResolvedValue({
      id: 'empresa-1',
      rol: 'negocio',
      activo: true,
      nombres: 'Ana',
      negocios: [{ id: 'n-1', estado: 'aprobado' }],
    } as any)
    negocioCreate.mockResolvedValue({ id: NEGOCIO_ID } as any)

    const res = await request(buildApp())
      .post('/api/auth/profile/negocios')
      .set('Authorization', `Bearer ${tokenFor('empresa-1')}`)
      .send({ nombre: 'Mariscos La Bahía', telefono: '314 000 0000', horario: 'Lun–Dom', latitud: 19.05, longitud: -104.31 })

    expect(res.status).toBe(201)
    expect(negocioCreate.mock.calls[0][0].data).toMatchObject({
      userId: 'empresa-1',
      nombre: 'Mariscos La Bahía',
      telefono: '314 000 0000',
      horario: 'Lun–Dom',
      latitud: 19.05,
      longitud: -104.31,
    })
    expect(notifyAdmins).toHaveBeenCalledWith('negocio_sugerido', 'Nuevo negocio sugerido', expect.any(String), NEGOCIO_ID)
  })

  it('rechaza una latitud fuera de rango', async () => {
    userFind.mockResolvedValue({ id: 'empresa-1', rol: 'negocio', activo: true, negocios: [] } as any)
    const res = await request(buildApp())
      .post('/api/auth/profile/negocios')
      .set('Authorization', `Bearer ${tokenFor('empresa-1')}`)
      .send({ nombre: 'X', latitud: 200, longitud: 0 })
    expect(res.status).toBe(400)
    expect(negocioCreate).not.toHaveBeenCalled()
  })

  it('GET /admin/negocios/:id devuelve el detalle con el contenido de RA ligado', async () => {
    comoAdmin()
    negocioFind.mockResolvedValue(detalleRow() as any)

    const res = await request(buildApp())
      .get(`/api/admin/negocios/${NEGOCIO_ID}`)
      .set('Authorization', `Bearer ${tokenFor('admin-1')}`)

    expect(res.status).toBe(200)
    expect(res.body.negocio).toMatchObject({
      id: NEGOCIO_ID,
      nombre: 'Mariscos La Bahía',
      latitud: 19.05,
      email: 'cafe@correo.com',
      marcadores: [{ nombre: 'menu_bahia' }],
      recorridos: [],
    })
  })

  it('"pendientes" no se confunde con un :negocioId', async () => {
    comoAdmin()
    negocioFindMany.mockResolvedValue([])
    const res = await request(buildApp())
      .get('/api/admin/negocios/pendientes')
      .set('Authorization', `Bearer ${tokenFor('admin-1')}`)
    // Lo atiende la ruta de la cola (no el detalle): no consulta un negocio.
    expect(negocioFind).not.toHaveBeenCalled()
    expect(res.status).toBe(200)
    expect(res.body.negocios).toEqual([])
  })

  it('PATCH /admin/negocios/:id edita los datos de la solicitud, incluido el contacto (null = borrar)', async () => {
    comoAdmin()
    negocioFind.mockResolvedValue({ id: NEGOCIO_ID } as any)
    negocioUpdate.mockResolvedValue(detalleRow({ nombre: 'Mariscos Centro', telefono: null, horario: 'Lun–Sáb' }) as any)

    const res = await request(buildApp())
      .patch(`/api/admin/negocios/${NEGOCIO_ID}`)
      .set('Authorization', `Bearer ${tokenFor('admin-1')}`)
      .send({ nombre: 'Mariscos Centro', telefono: null, horario: 'Lun–Sáb', latitud: 19.06, longitud: -104.32 })

    expect(res.status).toBe(200)
    expect(negocioUpdate.mock.calls[0][0]).toMatchObject({
      where: { id: NEGOCIO_ID },
      data: { nombre: 'Mariscos Centro', telefono: null, horario: 'Lun–Sáb', latitud: 19.06, longitud: -104.32 },
    })
    expect(res.body.negocio.nombre).toBe('Mariscos Centro')
  })

  it('PATCH responde 404 si el negocio no existe', async () => {
    comoAdmin()
    negocioFind.mockResolvedValue(null)
    const res = await request(buildApp())
      .patch(`/api/admin/negocios/${NEGOCIO_ID}`)
      .set('Authorization', `Bearer ${tokenFor('admin-1')}`)
      .send({ nombre: 'X' })
    expect(res.status).toBe(404)
    expect(negocioUpdate).not.toHaveBeenCalled()
  })

  it('el admin cambia la portada de la solicitud', async () => {
    comoAdmin()
    negocioFind.mockResolvedValue(detalleRow() as any)
    storageBucket.upload.mockResolvedValue({ error: null })
    storageBucket.getPublicUrl.mockReturnValue({ data: { publicUrl: 'https://cdn/negocio-assets/portada' } })
    negocioUpdate.mockResolvedValue({} as any)

    const res = await request(buildApp())
      .post(`/api/admin/negocios/${NEGOCIO_ID}/portada`)
      .set('Authorization', `Bearer ${tokenFor('admin-1')}`)
      .attach('file', Buffer.from('fake'), { filename: 'p.png', contentType: 'image/png' })

    expect(res.status).toBe(200)
    expect(storageBucket.upload.mock.calls[0][0]).toBe(`${NEGOCIO_ID}/portada`)
    expect(negocioUpdate.mock.calls[0][0]).toMatchObject({ where: { id: NEGOCIO_ID } })
  })

  it('una cuenta de empresa no puede usar las rutas de admin', async () => {
    userFind.mockResolvedValue({ id: 'empresa-1', rol: 'negocio', activo: true, negocios: [] } as any)
    const res = await request(buildApp())
      .patch(`/api/admin/negocios/${NEGOCIO_ID}`)
      .set('Authorization', `Bearer ${tokenFor('empresa-1')}`)
      .send({ nombre: 'X' })
    expect(res.status).toBe(403)
  })
})
