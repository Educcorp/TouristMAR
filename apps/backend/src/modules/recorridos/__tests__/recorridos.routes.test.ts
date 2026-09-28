import { describe, it, expect, vi, beforeEach, beforeAll } from 'vitest'
import express from 'express'
import request from 'supertest'
import jwt from 'jsonwebtoken'
import sharp from 'sharp'

vi.mock('../../../config/prisma', () => ({
  prisma: {
    user: { findUnique: vi.fn() },
    negocioProfile: { findUnique: vi.fn() },
    recorrido360: {
      findMany: vi.fn(),
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
    recorrido360Escena: {
      findUnique: vi.fn(),
      upsert: vi.fn(),
      delete: vi.fn(),
    },
  },
}))

const storageBucket = {
  upload: vi.fn(),
  getPublicUrl: vi.fn(),
  remove: vi.fn(),
}

vi.mock('../../../config/supabase', () => ({
  RECORRIDOS_360_BUCKET: 'recorridos-360',
  supabase: {
    storage: {
      getBucket: vi.fn().mockResolvedValue({ data: {}, error: null }),
      createBucket: vi.fn(),
      from: () => storageBucket,
    },
  },
}))

import { prisma } from '../../../config/prisma'
import { recorridosRouter, recorridosAdminRouter } from '../recorridos.routes'

const userFind = vi.mocked(prisma.user.findUnique)
const recorridoFindMany = vi.mocked(prisma.recorrido360.findMany)
const recorridoFind = vi.mocked(prisma.recorrido360.findUnique)
const recorridoFindFirst = vi.mocked(prisma.recorrido360.findFirst)
const recorridoCreate = vi.mocked(prisma.recorrido360.create)
const recorridoUpdate = vi.mocked(prisma.recorrido360.update)
const escenaFind = vi.mocked(prisma.recorrido360Escena.findUnique)
const escenaUpsert = vi.mocked(prisma.recorrido360Escena.upsert)
const escenaDelete = vi.mocked(prisma.recorrido360Escena.delete)

const RECORRIDO_ID = '22222222-2222-4222-8222-222222222222'
const ESCENA_1 = '33333333-3333-4333-8333-333333333331'
const ESCENA_2 = '33333333-3333-4333-8333-333333333332'
const ESCENA_3 = '33333333-3333-4333-8333-333333333333'

function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api/admin/recorridos', recorridosAdminRouter)
  app.use('/api/recorridos', recorridosRouter)
  return app
}

function tokenFor(id: string) {
  return jwt.sign({ sub: id }, process.env.JWT_SECRET!)
}

function escenaRow(id: string, orden: number, overrides: Record<string, unknown> = {}) {
  return {
    id,
    recorridoId: RECORRIDO_ID,
    orden,
    imagenUrl: `https://cdn/recorridos-360/${RECORRIDO_ID}/${id}.jpg`,
    imagenPath: `${RECORRIDO_ID}/${id}.jpg`,
    miniaturaUrl: `https://cdn/recorridos-360/${RECORRIDO_ID}/${id}_min.jpg`,
    miniaturaPath: `${RECORRIDO_ID}/${id}_min.jpg`,
    ancho: 4096,
    alto: 2048,
    pesoBytes: 1_200_000,
    createdAt: new Date('2026-09-01T00:00:00Z'),
    updatedAt: new Date('2026-09-01T00:00:00Z'),
    ...overrides,
  }
}

function recorridoRow(overrides: Record<string, unknown> = {}) {
  return {
    id: RECORRIDO_ID,
    negocioId: null,
    negocio: null,
    nombre: 'cerro_vigia_360',
    titulo: 'Cerro del Vigía',
    texto: 'Mirador con vista a la bahía.',
    activo: true,
    creadoPor: 'admin-1',
    createdAt: new Date('2026-09-01T00:00:00Z'),
    updatedAt: new Date('2026-09-02T00:00:00Z'),
    escenas: [escenaRow(ESCENA_1, 0), escenaRow(ESCENA_2, 1), escenaRow(ESCENA_3, 2)],
    ...overrides,
  }
}

function asAdmin() {
  userFind.mockResolvedValue({ id: 'admin-1', rol: 'admin', activo: true, negocios: [] } as any)
  return `Bearer ${tokenFor('admin-1')}`
}

// Fotos sintéticas reales: se prueba la optimización de verdad con sharp.
let foto360Grande: Buffer
let fotoCuadrada: Buffer

beforeAll(async () => {
  foto360Grande = await sharp({ create: { width: 6000, height: 3000, channels: 3, background: '#3a7bd5' } })
    .jpeg()
    .toBuffer()
  fotoCuadrada = await sharp({ create: { width: 2048, height: 2048, channels: 3, background: '#3a7bd5' } })
    .png()
    .toBuffer()
})

beforeEach(() => {
  vi.clearAllMocks()
  storageBucket.upload.mockResolvedValue({ error: null })
  storageBucket.remove.mockResolvedValue({ error: null })
  storageBucket.getPublicUrl.mockImplementation((path: string) => ({ data: { publicUrl: `https://cdn/recorridos-360/${path}` } }))
  recorridoFindFirst.mockResolvedValue(null)
})

describe('GET /api/recorridos', () => {
  it('es público y devuelve el contrato para Unity: 3 fotos en orden, sin nulls', async () => {
    recorridoFindMany.mockResolvedValue([recorridoRow()] as any)

    const res = await request(buildApp()).get('/api/recorridos')

    expect(res.status).toBe(200)
    expect(res.headers['cache-control']).toBe('no-cache')
    expect(res.body).toEqual({
      recorridos: [
        {
          nombre: 'cerro_vigia_360',
          textoParaMostrar: 'Cerro del Vigía\nMirador con vista a la bahía.',
          negocioId: '',
          urlPortada: `https://cdn/recorridos-360/${RECORRIDO_ID}/${ESCENA_1}_min.jpg`,
          escenas: [
            { titulo: 'Foto 1', urlImagen: `https://cdn/recorridos-360/${RECORRIDO_ID}/${ESCENA_1}.jpg` },
            { titulo: 'Foto 2', urlImagen: `https://cdn/recorridos-360/${RECORRIDO_ID}/${ESCENA_2}.jpg` },
            { titulo: 'Foto 3', urlImagen: `https://cdn/recorridos-360/${RECORRIDO_ID}/${ESCENA_3}.jpg` },
          ],
        },
      ],
    })
  })

  it('solo pide recorridos activos, con escenas y de negocios aprobados (o sin negocio)', async () => {
    recorridoFindMany.mockResolvedValue([])

    await request(buildApp()).get('/api/recorridos')

    expect(recorridoFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          activo: true,
          escenas: { some: {} },
          OR: [{ negocioId: null }, { negocio: { estado: 'aprobado' } }],
        },
      }),
    )
  })

  it('no publica un recorrido al que le faltan fotos (Unity espera las 3)', async () => {
    recorridoFindMany.mockResolvedValue([
      recorridoRow(),
      recorridoRow({ nombre: 'incompleto_360', escenas: [escenaRow(ESCENA_1, 0), escenaRow(ESCENA_2, 1)] }),
    ] as any)

    const res = await request(buildApp()).get('/api/recorridos')

    expect(res.body.recorridos.map((r: any) => r.nombre)).toEqual(['cerro_vigia_360'])
  })

  it('filtra por negocio con ?negocioId=', async () => {
    recorridoFindMany.mockResolvedValue([])
    const negocioId = '44444444-4444-4444-8444-444444444444'

    const res = await request(buildApp()).get(`/api/recorridos?negocioId=${negocioId}`)

    expect(res.status).toBe(200)
    expect(recorridoFindMany.mock.calls[0][0]!.where).toMatchObject({ negocioId })
  })

  it('un recorrido por nombre; 404 si está oculto', async () => {
    recorridoFind.mockResolvedValueOnce(recorridoRow() as any)
    const ok = await request(buildApp()).get('/api/recorridos/cerro_vigia_360')
    expect(ok.status).toBe(200)
    expect(ok.body.recorrido.escenas).toHaveLength(3)

    recorridoFind.mockResolvedValueOnce(recorridoRow({ activo: false }) as any)
    const oculto = await request(buildApp()).get('/api/recorridos/cerro_vigia_360')
    expect(oculto.status).toBe(404)
  })
})

describe('/api/admin/recorridos', () => {
  it('rechaza a un turista', async () => {
    userFind.mockResolvedValue({ id: 'turista-1', rol: 'turista', activo: true, negocios: [] } as any)

    const res = await request(buildApp())
      .get('/api/admin/recorridos')
      .set('Authorization', `Bearer ${tokenFor('turista-1')}`)

    expect(res.status).toBe(403)
  })

  it('un admin crea un recorrido (el nombre se normaliza a minúsculas)', async () => {
    const auth = asAdmin()
    recorridoCreate.mockImplementation(({ data }: any) => Promise.resolve(recorridoRow({ ...data, escenas: [] })) as any)

    const res = await request(buildApp())
      .post('/api/admin/recorridos')
      .set('Authorization', auth)
      .send({ nombre: 'Cerro_Vigia_360', titulo: 'Cerro del Vigía', texto: 'Mirador.', negocioId: null })

    expect(res.status).toBe(201)
    expect(recorridoCreate.mock.calls[0][0].data).toMatchObject({ nombre: 'cerro_vigia_360', creadoPor: 'admin-1' })
    expect(res.body.recorrido.escenas).toEqual([])
  })

  it('rechaza un nombre repetido con 409', async () => {
    const auth = asAdmin()
    recorridoFindFirst.mockResolvedValue({ id: 'otro' } as any)

    const res = await request(buildApp())
      .post('/api/admin/recorridos')
      .set('Authorization', auth)
      .send({ nombre: 'cerro_vigia_360', titulo: 'Cerro', texto: 'Texto' })

    expect(res.status).toBe(409)
    expect(recorridoCreate).not.toHaveBeenCalled()
  })

  it('rechaza nombres con espacios o acentos', async () => {
    const auth = asAdmin()

    const res = await request(buildApp())
      .patch(`/api/admin/recorridos/${RECORRIDO_ID}`)
      .set('Authorization', auth)
      .send({ nombre: 'Cerro del Vigía' })

    expect(res.status).toBe(400)
    expect(recorridoUpdate).not.toHaveBeenCalled()
  })
})

describe('/api/admin/recorridos/:id/escenas/:posicion', () => {
  it('sube la Foto 2 en su casilla, optimizada (máx. 4096×2048 JPG) y con miniatura', async () => {
    const auth = asAdmin()
    recorridoFind.mockResolvedValue(recorridoRow({ escenas: [escenaRow(ESCENA_1, 0)] }) as any)
    escenaUpsert.mockImplementation(({ create }: any) => Promise.resolve(escenaRow(ESCENA_2, create.orden, create)) as any)

    const res = await request(buildApp())
      .put(`/api/admin/recorridos/${RECORRIDO_ID}/escenas/2`)
      .set('Authorization', auth)
      .attach('file', foto360Grande, { filename: 'foto1.jpg', contentType: 'image/jpeg' })

    expect(res.status).toBe(200)
    expect(res.body.escena).toMatchObject({ posicion: 2, ancho: 4096, alto: 2048 })
    // La casilla decide el orden (no el nombre del archivo ni el orden de subida).
    expect(escenaUpsert.mock.calls[0][0].where).toEqual({ recorridoId_orden: { recorridoId: RECORRIDO_ID, orden: 1 } })

    const [imagenCall, miniaturaCall] = storageBucket.upload.mock.calls
    // Carpeta del recorrido + id único: dos recorridos nunca comparten archivo.
    expect(imagenCall[0]).toMatch(new RegExp(`^${RECORRIDO_ID}/[0-9a-f-]+\\.jpg$`))
    expect(imagenCall[2]).toMatchObject({ contentType: 'image/jpeg', cacheControl: '31536000' })
    const imagen = await sharp(imagenCall[1]).metadata()
    expect(imagen).toMatchObject({ format: 'jpeg', width: 4096, height: 2048, isProgressive: false })
    const miniatura = await sharp(miniaturaCall[1]).metadata()
    expect(miniatura).toMatchObject({ width: 640, height: 320 })
    expect(storageBucket.remove).not.toHaveBeenCalled()
  })

  it('reemplazar una foto borra los archivos de la anterior', async () => {
    const auth = asAdmin()
    recorridoFind.mockResolvedValue(recorridoRow() as any)
    escenaUpsert.mockImplementation(({ update }: any) => Promise.resolve(escenaRow(ESCENA_1, 0, update)) as any)

    const res = await request(buildApp())
      .put(`/api/admin/recorridos/${RECORRIDO_ID}/escenas/1`)
      .set('Authorization', auth)
      .attach('file', foto360Grande, { filename: 'nueva.jpg', contentType: 'image/jpeg' })

    expect(res.status).toBe(200)
    expect(storageBucket.remove).toHaveBeenCalledWith([`${RECORRIDO_ID}/${ESCENA_1}.jpg`, `${RECORRIDO_ID}/${ESCENA_1}_min.jpg`])
  })

  it('solo hay casillas 1, 2 y 3', async () => {
    const auth = asAdmin()

    const res = await request(buildApp())
      .put(`/api/admin/recorridos/${RECORRIDO_ID}/escenas/4`)
      .set('Authorization', auth)
      .attach('file', foto360Grande, { filename: 'x.jpg', contentType: 'image/jpeg' })

    expect(res.status).toBe(400)
    expect(storageBucket.upload).not.toHaveBeenCalled()
  })

  it('rechaza una foto que no es 2:1 sin subir nada', async () => {
    const auth = asAdmin()
    recorridoFind.mockResolvedValue(recorridoRow() as any)

    const res = await request(buildApp())
      .put(`/api/admin/recorridos/${RECORRIDO_ID}/escenas/1`)
      .set('Authorization', auth)
      .attach('file', fotoCuadrada, { filename: 'cuadrada.png', contentType: 'image/png' })

    expect(res.status).toBe(400)
    expect(res.body.error).toMatch(/2:1/)
    expect(storageBucket.upload).not.toHaveBeenCalled()
    expect(escenaUpsert).not.toHaveBeenCalled()
  })

  it('rechaza un archivo que no es imagen', async () => {
    const auth = asAdmin()
    recorridoFind.mockResolvedValue(recorridoRow() as any)

    const res = await request(buildApp())
      .put(`/api/admin/recorridos/${RECORRIDO_ID}/escenas/1`)
      .set('Authorization', auth)
      .attach('file', Buffer.from('no soy una foto'), { filename: 'x.jpg', contentType: 'image/jpeg' })

    expect(res.status).toBe(400)
    expect(storageBucket.upload).not.toHaveBeenCalled()
  })

  it('quita la foto de una casilla', async () => {
    const auth = asAdmin()
    escenaFind.mockResolvedValue(escenaRow(ESCENA_3, 2) as any)

    const res = await request(buildApp())
      .delete(`/api/admin/recorridos/${RECORRIDO_ID}/escenas/3`)
      .set('Authorization', auth)

    expect(res.status).toBe(204)
    expect(escenaFind).toHaveBeenCalledWith({ where: { recorridoId_orden: { recorridoId: RECORRIDO_ID, orden: 2 } } })
    expect(escenaDelete).toHaveBeenCalledWith({ where: { id: ESCENA_3 } })
  })

  it('al borrar el recorrido borra también sus fotos de Storage', async () => {
    const auth = asAdmin()
    recorridoFind.mockResolvedValue(recorridoRow() as any)

    const res = await request(buildApp()).delete(`/api/admin/recorridos/${RECORRIDO_ID}`).set('Authorization', auth)

    expect(res.status).toBe(204)
    expect(storageBucket.remove).toHaveBeenCalledWith(
      [ESCENA_1, ESCENA_2, ESCENA_3].flatMap((id) => [`${RECORRIDO_ID}/${id}.jpg`, `${RECORRIDO_ID}/${id}_min.jpg`]),
    )
  })
})
