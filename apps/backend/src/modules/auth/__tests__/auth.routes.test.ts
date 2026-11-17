import { describe, it, expect, vi, beforeEach } from 'vitest'
import express from 'express'
import request from 'supertest'
import bcrypt from 'bcryptjs'

// Sin red en las pruebas: el dominio del correo siempre "existe".
vi.mock('../email-domain', () => ({ dominioDeCorreoExiste: vi.fn().mockResolvedValue(true) }))

// Sin correos reales: se captura lo que se habría mandado por Brevo.
vi.mock('../../../config/mail', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../../config/mail')>()),
  enviarCorreo: vi.fn(),
}))

vi.mock('../../../config/prisma', () => ({
  prisma: {
    user: {
      findUnique: vi.fn(),
      findMany: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
    },
    notification: {
      createMany: vi.fn(),
    },
    recuperacionPassword: {
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
      deleteMany: vi.fn(),
    },
    $transaction: vi.fn(),
  },
}))

import { prisma } from '../../../config/prisma'
import { enviarCorreo, MailNotConfiguredError } from '../../../config/mail'
import { authRouter } from '../auth.routes'

const findUnique = vi.mocked(prisma.user.findUnique)
const findMany = vi.mocked(prisma.user.findMany)
const create = vi.mocked(prisma.user.create)

function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api/auth', authRouter)
  return app
}

beforeEach(() => {
  vi.clearAllMocks()
  // Sin admins registrados en estos tests: notifyAdmins() se vuelve un no-op.
  findMany.mockResolvedValue([])
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

describe('Recuperar contraseña', () => {
  const recuperacion = vi.mocked(prisma.recuperacionPassword)
  const enviar = vi.mocked(enviarCorreo)
  const ana = { id: 'user-1', email: 'ana@correo.com', nombres: 'Ana', activo: true } as any

  /// Pide un código para Ana y devuelve el que "llegó" por correo y el
  /// registro que se guardó en la base.
  async function pedirCodigo() {
    findUnique.mockResolvedValue(ana)
    recuperacion.findFirst.mockResolvedValue(null)
    recuperacion.create.mockImplementation(({ data }: any) => Promise.resolve({ id: 'rec-1', intentos: 0, ...data }))
    const res = await request(buildApp()).post('/api/auth/forgot-password').send({ email: 'ana@correo.com' })
    expect(res.status).toBe(200)
    const correo = enviar.mock.calls[0][0]
    const codigo = /\b(\d{6})\b/.exec(correo.texto)![1]
    const guardado = (recuperacion.create.mock.calls[0][0] as any).data
    return { codigo, guardado, correo }
  }

  it('manda un código de 6 dígitos al correo y solo guarda su hash', async () => {
    const { codigo, guardado, correo } = await pedirCodigo()
    expect(correo.para).toBe('ana@correo.com')
    expect(guardado.codigoHash).not.toContain(codigo)
    expect(guardado.expiraEn.getTime()).toBeGreaterThan(Date.now())
  })

  it('responde igual si el correo no tiene cuenta, sin mandar nada', async () => {
    findUnique.mockResolvedValue(null)
    const res = await request(buildApp()).post('/api/auth/forgot-password').send({ email: 'nadie@correo.com' })
    expect(res.status).toBe(200)
    expect(enviar).not.toHaveBeenCalled()
  })

  it('no manda otro código si ya se pidió uno hace menos de un minuto', async () => {
    findUnique.mockResolvedValue(ana)
    recuperacion.findFirst.mockResolvedValue({ id: 'rec-0' } as any)
    const res = await request(buildApp()).post('/api/auth/forgot-password').send({ email: 'ana@correo.com' })
    expect(res.status).toBe(200)
    expect(enviar).not.toHaveBeenCalled()
  })

  it('responde 503 si el correo no está configurado y borra el código', async () => {
    findUnique.mockResolvedValue(ana)
    recuperacion.findFirst.mockResolvedValue(null)
    recuperacion.create.mockResolvedValue({ id: 'rec-1' } as any)
    recuperacion.delete.mockResolvedValue({} as any)
    enviar.mockRejectedValueOnce(new MailNotConfiguredError('sin correo'))
    const res = await request(buildApp()).post('/api/auth/forgot-password').send({ email: 'ana@correo.com' })
    expect(res.status).toBe(503)
    expect(recuperacion.delete).toHaveBeenCalledWith({ where: { id: 'rec-1' } })
  })

  it('con el código correcto cambia la contraseña', async () => {
    const { codigo, guardado } = await pedirCodigo()
    recuperacion.findFirst.mockResolvedValue({ id: 'rec-1', intentos: 0, ...guardado })
    vi.mocked(prisma.$transaction).mockResolvedValue([] as any)

    const res = await request(buildApp())
      .post('/api/auth/reset-password')
      .send({ email: 'ana@correo.com', codigo, password: 'NuevaClave#2026' })

    expect(res.status).toBe(200)
    const nuevoHash = (vi.mocked(prisma.user.update).mock.calls[0][0] as any).data.passwordHash as string
    expect(await bcrypt.compare('NuevaClave#2026', nuevoHash)).toBe(true)
    expect(prisma.$transaction).toHaveBeenCalled()
  })

  it('con un código incorrecto responde 400 y cuenta el intento', async () => {
    const { codigo, guardado } = await pedirCodigo()
    recuperacion.findFirst.mockResolvedValue({ id: 'rec-1', intentos: 0, ...guardado })
    const otro = codigo === '000000' ? '111111' : '000000'

    const res = await request(buildApp())
      .post('/api/auth/reset-password')
      .send({ email: 'ana@correo.com', codigo: otro, password: 'NuevaClave#2026' })

    expect(res.status).toBe(400)
    expect(recuperacion.update).toHaveBeenCalledWith({ where: { id: 'rec-1' }, data: { intentos: 1 } })
    expect(prisma.$transaction).not.toHaveBeenCalled()
  })

  it('al quinto intento fallido invalida el código', async () => {
    const { codigo, guardado } = await pedirCodigo()
    recuperacion.findFirst.mockResolvedValue({ id: 'rec-1', ...guardado, intentos: 4 })
    const otro = codigo === '000000' ? '111111' : '000000'

    const res = await request(buildApp())
      .post('/api/auth/reset-password')
      .send({ email: 'ana@correo.com', codigo: otro, password: 'NuevaClave#2026' })

    expect(res.status).toBe(400)
    expect(res.body.error).toMatch(/Demasiados intentos/)
    const data = recuperacion.update.mock.calls[0][0].data as any
    expect(data.intentos).toBe(5)
    expect(data.usadoEn).toBeInstanceOf(Date)
  })

  it('rechaza un código caducado o inexistente', async () => {
    findUnique.mockResolvedValue(ana)
    recuperacion.findFirst.mockResolvedValue(null)
    const res = await request(buildApp())
      .post('/api/auth/reset-password')
      .send({ email: 'ana@correo.com', codigo: '123456', password: 'NuevaClave#2026' })
    expect(res.status).toBe(400)
  })

  it('valida el formato del código y la longitud de la contraseña', async () => {
    const res = await request(buildApp())
      .post('/api/auth/reset-password')
      .send({ email: 'ana@correo.com', codigo: '12ab', password: 'corta' })
    expect(res.status).toBe(400)
    expect(findUnique).not.toHaveBeenCalled()
  })
})
