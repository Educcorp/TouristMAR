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
      findFirst: vi.fn(),
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
import { marcadoresRouter, arAdminRouter } from '../ar.routes'

const userFind = vi.mocked(prisma.user.findUnique)
const marcadorFindMany = vi.mocked(prisma.arMarcador.findMany)
const marcadorFind = vi.mocked(prisma.arMarcador.findUnique)
const marcadorFindFirst = vi.mocked(prisma.arMarcador.findFirst)
const marcadorUpdate = vi.mocked(prisma.arMarcador.update)
const marcadorCreate = vi.mocked(prisma.arMarcador.create)
const escaneoCreate = vi.mocked(prisma.arEscaneo.create)

const MARCADOR_ID = '11111111-1111-4111-8111-111111111111'

function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api/admin/ar', arAdminRouter)
  app.use('/api/marcadores', marcadoresRouter)
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
    nombre: 'gaviota_01',
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
  marcadorFindFirst.mockResolvedValue(null)
})

describe('GET /api/marcadores', () => {
  it('es público y devuelve EXACTAMENTE el contrato acordado con Unity', async () => {
    marcadorFindMany.mockResolvedValue([marcadorRow()] as any)

    const res = await request(buildApp()).get('/api/marcadores')

    expect(res.status).toBe(200)
    expect(res.headers['cache-control']).toBe('no-cache')
    expect(res.body).toEqual({
      marcadores: [
        {
          nombre: 'gaviota_01',
          urlImagen: 'https://cdn/ar-marcadores/x/marcador?v=1',
          textoParaMostrar: 'Gaviota patiamarilla\nAve común en la bahía de Manzanillo.',
        },
      ],
    })
  })

  it('solo pide marcadores activos y de negocios aprobados (o sin negocio)', async () => {
    marcadorFindMany.mockResolvedValue([])

    await request(buildApp()).get('/api/marcadores')

    expect(marcadorFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { activo: true, OR: [{ negocioId: null }, { negocio: { estado: 'aprobado' } }] },
      }),
    )
  })

  it('con ?negocioId= devuelve solo los marcadores de ese lugar (RA geo → marcadores)', async () => {
    marcadorFindMany.mockResolvedValue([])
    const lugar = 'f24442e4-6613-4427-99df-a7f962d6b99e'

    const res = await request(buildApp()).get(`/api/marcadores?negocioId=${lugar}`)

    expect(res.status).toBe(200)
    expect(marcadorFindMany.mock.calls[0][0]).toMatchObject({ where: { activo: true, negocioId: lugar } })
  })

  it('un negocioId vacío es como no mandarlo; uno inválido es 400', async () => {
    marcadorFindMany.mockResolvedValue([])

    const vacio = await request(buildApp()).get('/api/marcadores?negocioId=')
    const invalido = await request(buildApp()).get('/api/marcadores?negocioId=fime')

    expect(vacio.status).toBe(200)
    expect(marcadorFindMany.mock.calls[0][0].where).not.toHaveProperty('negocioId')
    expect(invalido.status).toBe(400)
  })
})

describe('POST /api/marcadores/:nombre/escaneo', () => {
  it('registra el escaneo anónimo buscando el marcador por nombre', async () => {
    marcadorFind.mockResolvedValue({ id: MARCADOR_ID, activo: true } as any)

    const res = await request(buildApp()).post('/api/marcadores/gaviota_01/escaneo').send({ plataforma: 'android' })

    expect(res.status).toBe(204)
    expect(marcadorFind).toHaveBeenCalledWith(expect.objectContaining({ where: { nombre: 'gaviota_01' } }))
    expect(escaneoCreate).toHaveBeenCalledWith({ data: { marcadorId: MARCADOR_ID, userId: null, plataforma: 'android' } })
  })

  it('asocia el escaneo al turista si viene un token válido', async () => {
    marcadorFind.mockResolvedValue({ id: MARCADOR_ID, activo: true } as any)
    userFind.mockResolvedValue({ id: 'turista-1', rol: 'turista', activo: true, negocios: [] } as any)

    const res = await request(buildApp())
      .post('/api/marcadores/gaviota_01/escaneo')
      .set('Authorization', `Bearer ${tokenFor('turista-1')}`)
      .send({})

    expect(res.status).toBe(204)
    expect(escaneoCreate).toHaveBeenCalledWith({ data: { marcadorId: MARCADOR_ID, userId: 'turista-1', plataforma: null } })
  })

  it('404 si el marcador no existe o está desactivado', async () => {
    marcadorFind.mockResolvedValue({ id: MARCADOR_ID, activo: false } as any)

    const res = await request(buildApp()).post('/api/marcadores/gaviota_01/escaneo').send({})

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
      .field('nombre', 'Barco_02')
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
    // El nombre se normaliza a minúsculas: es el identificador para Unity.
    expect(data).toMatchObject({ nombre: 'barco_02', anchoMetros: 0.3, negocioId: null, creadoPor: 'admin-1' })
    expect(data.imagenPath).toBe(`${data.id}/marcador`)
  })

  it('rechaza un nombre repetido con 409 (Unity no distinguiría los marcadores)', async () => {
    userFind.mockResolvedValue({ id: 'admin-1', rol: 'admin', activo: true, negocios: [] } as any)
    marcadorFindFirst.mockResolvedValue({ id: 'otro' } as any)

    const res = await request(buildApp())
      .post('/api/admin/ar/marcadores')
      .set('Authorization', `Bearer ${tokenFor('admin-1')}`)
      .field('nombre', 'gaviota_01')
      .field('titulo', 'Gaviota')
      .field('texto', 'Texto')
      .attach('file', Buffer.from('fake-png'), { filename: 'g.png', contentType: 'image/png' })

    expect(res.status).toBe(409)
    expect(storageBucket.upload).not.toHaveBeenCalled()
  })

  it('rechaza nombres con espacios o acentos', async () => {
    userFind.mockResolvedValue({ id: 'admin-1', rol: 'admin', activo: true, negocios: [] } as any)

    const res = await request(buildApp())
      .patch(`/api/admin/ar/marcadores/${MARCADOR_ID}`)
      .set('Authorization', `Bearer ${tokenFor('admin-1')}`)
      .send({ nombre: 'Gaviota del pacífico' })

    expect(res.status).toBe(400)
    expect(marcadorUpdate).not.toHaveBeenCalled()
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
