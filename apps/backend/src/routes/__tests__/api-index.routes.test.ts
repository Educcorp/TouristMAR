import { describe, it, expect, vi } from 'vitest'
import express from 'express'
import request from 'supertest'

vi.mock('../../config/prisma', () => ({ prisma: {} }))

import { apiRouter } from '../index'

function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api', apiRouter)
  return app
}

describe('/api', () => {
  it('la base responde en JSON que la API está arriba y lista las rutas públicas', async () => {
    const res = await request(buildApp()).get('/api')

    expect(res.status).toBe(200)
    expect(res.type).toMatch(/json/)
    expect(res.body).toMatchObject({ estado: 'ok', endpointsPublicos: { raLugar: '/api/ra/lugares/{lugarId}' } })
  })

  it('una ruta que no existe responde 404 en JSON, no en HTML', async () => {
    const res = await request(buildApp()).get('/api/ra/no-existe/ni-esta')

    expect(res.status).toBe(404)
    expect(res.type).toMatch(/json/)
    expect(res.body.error).toBe('No existe GET /api/ra/no-existe/ni-esta')
  })
})
