import { describe, it, expect, vi, beforeEach } from 'vitest'
import express from 'express'
import request from 'supertest'
import bcrypt from 'bcryptjs'

vi.mock('../../../config/prisma', () => ({
  prisma: {
    user: {
      findUnique: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
  },
}))

import { prisma } from '../../../config/prisma'
import { authRouter } from '../auth.routes'

const findUnique = vi.mocked(prisma.user.findUnique)
const create = vi.mocked(prisma.user.create)

function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api/auth', authRouter)
  return app
}

beforeEach(() => {
  vi.clearAllMocks()
})

describe('POST /api/auth/register', () => {
  it('crea la cuenta y devuelve token + usuario público (sin passwordHash)', async () => {
    findUnique.mockResolvedValue(null)
    create.mockImplementation(({ data }: any) =>
      Promise.resolve({ id: 'user-1', avatarUrl: null, bio: null, ...data, negocios: data.negocios ?? [] }) as any,
    )

    const res = await request(buildApp()).post('/api/auth/register').send({
      email: 'ana@correo.com',
      password: 'password123',
      name: 'Ana',
    })

    expect(res.status).toBe(201)
    expect(res.body.user).toEqual({
      id: 'user-1',
      email: 'ana@correo.com',
      name: 'Ana',
      role: 'turista',
      avatarUrl: null,
      bio: null,
      negocios: [],
    })
    expect(res.body.user.passwordHash).toBeUndefined()
    expect(typeof res.body.token).toBe('string')
  })

  it('responde 400 con datos inválidos (email mal formado, password corto)', async () => {
    const res = await request(buildApp()).post('/api/auth/register').send({
      email: 'no-es-un-correo',
      password: '123',
      name: '',
    })

    expect(res.status).toBe(400)
    expect(create).not.toHaveBeenCalled()
  })
})

describe('POST /api/auth/login', () => {
  it('devuelve 401 con credenciales incorrectas', async () => {
    findUnique.mockResolvedValue(null)

    const res = await request(buildApp()).post('/api/auth/login').send({
      email: 'nadie@correo.com',
      password: 'password123',
    })

    expect(res.status).toBe(401)
  })

  it('devuelve token + usuario con credenciales correctas', async () => {
    const passwordHash = await bcrypt.hash('password123', 10)
    findUnique.mockResolvedValue({
      id: 'user-1',
      email: 'ana@correo.com',
      passwordHash,
      nombres: 'Ana',
      rol: 'turista',
      avatarUrl: null,
      negocios: [],
    } as any)

    const res = await request(buildApp()).post('/api/auth/login').send({
      email: 'ana@correo.com',
      password: 'password123',
    })

    expect(res.status).toBe(200)
    expect(res.body.user.email).toBe('ana@correo.com')
  })
})

describe('GET /api/auth/me', () => {
  it('responde 401 sin token', async () => {
    const res = await request(buildApp()).get('/api/auth/me')
    expect(res.status).toBe(401)
  })
})

describe('GET /api/auth/google', () => {
  it('responde 503 cuando Google OAuth no está configurado en el servidor', async () => {
    const res = await request(buildApp()).get('/api/auth/google')
    expect(res.status).toBe(503)
  })
})
