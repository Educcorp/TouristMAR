import { describe, it, expect, vi, beforeEach } from 'vitest'
import express from 'express'
import request from 'supertest'

vi.mock('../../../config/prisma', () => ({
  prisma: { negocioProfile: { findMany: vi.fn() } },
}))

import { prisma } from '../../../config/prisma'
import { raLugaresRouter } from '../lugares.routes'

const FIME_ID = 'f24442e4-6613-4427-99df-a7f962d6b99e'

const fila = (data: Record<string, unknown>) => ({
  id: 'x',
  nombre: 'Lugar',
  categoria: null,
  descripcion: null,
  direccion: null,
  portada: null,
  latitud: 19,
  longitud: -104,
  estado: 'aprobado',
  puntosRaGeo: [],
  _count: { arMarcadores: 0 },
  ...data,
})

function buildApp() {
  const app = express()
  app.use('/api/ra/lugares', raLugaresRouter)
  return app
}

beforeEach(() => {
  vi.mocked(prisma.negocioProfile.findMany).mockResolvedValue([
    fila({ id: FIME_ID, nombre: 'Facultad de ingenieria electromecanica', latitud: 19.12397051892223, longitud: -104.4000125955125 }),
    fila({ id: 'otro', nombre: 'Mariscos El Faro', descripcion: 'Mariscos frescos', categoria: 'Restaurante' }),
  ] as any)
})

describe('GET /api/ra/lugares (contrato con Unity)', () => {
  it('solo pide lugares aprobados con pin', async () => {
    await request(buildApp()).get('/api/ra/lugares')
    expect(vi.mocked(prisma.negocioProfile.findMany).mock.calls[0][0]).toMatchObject({
      where: { estado: 'aprobado', latitud: { not: null }, longitud: { not: null } },
      include: { puntosRaGeo: { where: { activo: true } }, _count: { select: { arMarcadores: { where: { activo: true } } } } },
    })
  })

  it('busca sin importar acentos ni mayúsculas y nunca manda null', async () => {
    const res = await request(buildApp()).get('/api/ra/lugares?buscar=Electromecánica')

    expect(res.status).toBe(200)
    expect(res.body.lugares).toEqual([
      {
        id: FIME_ID,
        nombre: 'Facultad de ingenieria electromecanica',
        categoria: '',
        textoParaMostrar: 'Facultad de ingenieria electromecanica',
        direccion: '',
        urlPortada: '',
        latitud: 19.12397051892223,
        longitud: -104.4000125955125,
        // Sin puntos dados de alta: el pin del lugar hace de punto único.
        puntos: [
          {
            id: FIME_ID,
            titulo: 'Facultad de ingenieria electromecanica',
            resumen: '',
            detalle: '',
            urlImagen: '',
            urlAudio: '',
            latitud: 19.12397051892223,
            longitud: -104.4000125955125,
            radioVisible: 100,
            radioCercano: 10,
          },
        ],
        tieneMarcadores: false,
      },
    ])
  })

  it('avisa si el lugar tiene marcadores de imagen activos', async () => {
    vi.mocked(prisma.negocioProfile.findMany).mockResolvedValue([fila({ id: FIME_ID, _count: { arMarcadores: 2 } })] as any)
    const res = await request(buildApp()).get(`/api/ra/lugares/${FIME_ID}`)
    expect(res.body.lugar.tieneMarcadores).toBe(true)
  })

  it('con puntos dados de alta manda esos, con sus dos radios', async () => {
    vi.mocked(prisma.negocioProfile.findMany).mockResolvedValue([
      fila({
        id: FIME_ID,
        nombre: 'FIME',
        puntosRaGeo: [
          {
            id: 'p-1',
            titulo: 'Entrada principal',
            resumen: 'Acceso por la carretera',
            detalle: 'Historia de la facultad…',
            imagenUrl: 'https://cdn.test/entrada.jpg',
            audioUrl: '',
            latitud: 19.1239,
            longitud: -104.4001,
            radioVisible: 80,
            radioCercano: 8,
          },
        ],
      }),
    ] as any)

    const res = await request(buildApp()).get(`/api/ra/lugares/${FIME_ID}`)

    expect(res.body.lugar.puntos).toEqual([
      {
        id: 'p-1',
        titulo: 'Entrada principal',
        resumen: 'Acceso por la carretera',
        detalle: 'Historia de la facultad…',
        urlImagen: 'https://cdn.test/entrada.jpg',
        urlAudio: '',
        latitud: 19.1239,
        longitud: -104.4001,
        radioVisible: 80,
        radioCercano: 8,
      },
    ])
  })

  it('textoParaMostrar lleva el nombre y la descripción en dos líneas', async () => {
    const res = await request(buildApp()).get('/api/ra/lugares/otro')
    expect(res.body.lugar.textoParaMostrar).toBe('Mariscos El Faro\nMariscos frescos')
  })

  it('404 si el lugar no existe o no tiene pin', async () => {
    const res = await request(buildApp()).get('/api/ra/lugares/no-existe')
    expect(res.status).toBe(404)
  })
})
