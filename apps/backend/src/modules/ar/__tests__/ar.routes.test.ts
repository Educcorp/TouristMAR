import { describe, it, expect, vi, beforeEach } from 'vitest'
import express from 'express'
import request from 'supertest'
import jwt from 'jsonwebtoken'

vi.mock('../../../config/prisma', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    negocioProfile: { findUnique: vi.fn() },
    arMarcador: {
      findMany: vi.fn(),
      findUnique: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
    arEscaneo: { create: vi.fn() },
  },
}))

const storageBucket = {
  upload: vi.fn(),
  getPublicUrl: vi.fn(),
  remove: vi.fn(),
}

vi.mock('../../../config/supabase', () => ({
  AR_MARCADORES_BUCKET: 'ar-marcadores',
  supabase: {
    storage: {
      getBucket: vi.fn().mockResolvedValue({ data: {}, error: null }),
      createBucket: vi.fn(),
      from: () => storageBucket,
    },
  },
}))

import { prisma } from '../../../config/prisma'
import { arRouter, arAdminRouter } from '../ar.routes'

const userFind = vi.mocked(prisma.user.findUnique)
const marcadorFindMany = vi.mocked(prisma.arMarcador.findMany)
const marcadorFind = vi.mocked(prisma.arMarcador.findUnique)
const marcadorCreate = vi.mocked(prisma.arMarcador.create)
const escaneoCreate = vi.mocked(prisma.arEscaneo.create)

const MARCADOR_ID = '11111111-1111-4111-8111-111111111111'

function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api/admin/ar', arAdminRouter)
  app.use('/api/ar', arRouter)
  return app
}

function tokenFor(id: string) {
  return jwt.sign({ sub: id }, process.env.JWT_SECRET!)
}

function marcadorRow(overrides: Record<string, unknown> = {}) {
  return {
    id: MARCADOR_ID,
    negocioId: null,
    negocio: null,
    nombre: 'Gaviota',
    imagenUrl: 'https://cdn/ar-marcadores/x/marcador?v=1',
    imagenPath: `${MARCADOR_ID}/marcador`,
    anchoMetros: null,
    titulo: 'Gaviota patiamarilla',
    texto: 'Ave común en la bahía de Manzanillo.',
    tipoContenido: 'texto',
    contenidoUrl: null,
    activo: true,
    creadoPor: 'admin-1',
    createdAt: new Date('2026-09-01T00:00:00Z'),
    updatedAt: new Date('2026-09-02T00:00:00Z'),
    _count: { escaneos: 0 },
    ...overrides,
  }
}

beforeEach(() => {
  vi.clearAllMocks()
  storageBucket.upload.mockResolvedValue({ error: null })
  storageBucket.getPublicUrl.mockReturnValue({ data: { publicUrl: 'https://cdn/ar-marcadores/x/marcador' } })
})

describe('GET /api/ar/marcadores', () => {
  it('es público y devuelve un objeto raíz sin nulls (compatible con JsonUtility)', async () => {
    marcadorFindMany.mockResolvedValue([marcadorRow()] as any)

    const res = await request(buildApp()).get('/api/ar/marcadores')

    expect(res.status).toBe(200)
    expect(res.body.version).toBe('2026-09-02T00:00:00.000Z')
    expect(res.body.marcadores).toEqual([
      {
        id: MARCADOR_ID,
        nombre: 'Gaviota',
        imagenUrl: 'https://cdn/ar-marcadores/x/marcador?v=1',
        anchoMetros: 0,
        titulo: 'Gaviota patiamarilla',
        texto: 'Ave común en la bahía de Manzanillo.',
        tipoContenido: 'texto',
        contenidoUrl: '',
        negocioId: '',
        negocioNombre: '',
        actualizadoEn: '2026-09-02T00:00:00.000Z',
      },
    ])
  })

  it('solo pide marcadores activos y de negocios aprobados (o sin negocio)', async () => {
    marcadorFindMany.mockResolvedValue([])

    await request(buildApp()).get('/api/ar/marcadores')

    expect(marcadorFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { activo: true, OR: [{ negocioId: null }, { negocio: { estado: 'aprobado' } }] },
      }),
    )
  })
})

describe('POST /api/ar/marcadores/:id/escaneo', () => {
  it('registra el escaneo anónimo', async () => {
    marcadorFind.mockResolvedValue({ activo: true } as any)

    const res = await request(buildApp()).post(`/api/ar/marcadores/${MARCADOR_ID}/escaneo`).send({ plataforma: 'android' })

    expect(res.status).toBe(204)
    expect(escaneoCreate).toHaveBeenCalledWith({ data: { marcadorId: MARCADOR_ID, userId: null, plataforma: 'android' } })
  })

  it('asocia el escaneo al turista si viene un token válido', async () => {
    marcadorFind.mockResolvedValue({ activo: true } as any)
    userFind.mockResolvedValue({ id: 'turista-1', rol: 'turista', activo: true, negocios: [] } as any)

    const res = await request(buildApp())
      .post(`/api/ar/marcadores/${MARCADOR_ID}/escaneo`)
      .set('Authorization', `Bearer ${tokenFor('turista-1')}`)
      .send({})

    expect(res.status).toBe(204)
    expect(escaneoCreate).toHaveBeenCalledWith({ data: { marcadorId: MARCADOR_ID, userId: 'turista-1', plataforma: null } })
  })

  it('404 si el marcador no existe o está desactivado', async () => {
    marcadorFind.mockResolvedValue({ activo: false } as any)

    const res = await request(buildApp()).post(`/api/ar/marcadores/${MARCADOR_ID}/escaneo`).send({})

    expect(res.status).toBe(404)
    expect(escaneoCreate).not.toHaveBeenCalled()
  })
})

describe('/api/admin/ar/marcadores', () => {
  it('rechaza a un turista', async () => {
    userFind.mockResolvedValue({ id: 'turista-1', rol: 'turista', activo: true, negocios: [] } as any)

    const res = await request(buildApp())
      .get('/api/admin/ar/marcadores')
      .set('Authorization', `Bearer ${tokenFor('turista-1')}`)

    expect(res.status).toBe(403)
  })

  it('un admin crea un marcador subiendo la imagen', async () => {
    userFind.mockResolvedValue({ id: 'admin-1', rol: 'admin', activo: true, negocios: [] } as any)
    marcadorCreate.mockImplementation(({ data }: any) => Promise.resolve(marcadorRow(data)) as any)

    const res = await request(buildApp())
      .post('/api/admin/ar/marcadores')
      .set('Authorization', `Bearer ${tokenFor('admin-1')}`)
      .field('nombre', 'Barco')
      .field('titulo', 'Barco pesquero')
      .field('texto', 'Flota tradicional del puerto.')
      .field('anchoMetros', '0.3')
      .field('negocioId', '')
      .attach('file', Buffer.from('fake-png'), { filename: 'barco.png', contentType: 'image/png' })

    expect(res.status).toBe(201)
    expect(storageBucket.upload).toHaveBeenCalledWith(expect.stringMatching(/\/marcador$/), expect.any(Buffer), {
      contentType: 'image/png',
      upsert: true,
    })
    const data = marcadorCreate.mock.calls[0][0].data as any
    expect(data).toMatchObject({ nombre: 'Barco', anchoMetros: 0.3, negocioId: null, creadoPor: 'admin-1' })
    expect(data.imagenPath).toBe(`${data.id}/marcador`)
  })

  it('rechaza imágenes que Unity no puede decodificar (webp)', async () => {
    userFind.mockResolvedValue({ id: 'admin-1', rol: 'admin', activo: true, negocios: [] } as any)

    const res = await request(buildApp())
      .post('/api/admin/ar/marcadores')
      .set('Authorization', `Bearer ${tokenFor('admin-1')}`)
      .field('nombre', 'Barco')
      .field('titulo', 'Barco')
      .field('texto', 'Texto')
      .attach('file', Buffer.from('fake-webp'), { filename: 'barco.webp', contentType: 'image/webp' })

    expect(res.status).toBe(400)
    expect(storageBucket.upload).not.toHaveBeenCalled()
  })
})
