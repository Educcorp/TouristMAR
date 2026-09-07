import { describe, it, expect, vi, beforeEach } from 'vitest'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import type { Profile } from 'passport-google-oauth20'

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
import {
  registerUser,
  validateCredentials,
  findOrCreateGoogleUser,
  signToken,
} from '../auth.service'

const findUnique = vi.mocked(prisma.user.findUnique)
const create = vi.mocked(prisma.user.create)
const update = vi.mocked(prisma.user.update)

beforeEach(() => {
  vi.clearAllMocks()
})

describe('registerUser', () => {
  it('hashea la contraseña y crea el usuario cuando el correo está libre', async () => {
    findUnique.mockResolvedValue(null)
    create.mockImplementation(({ data }: any) => Promise.resolve({ id: 'user-1', ...data }) as any)

    const user = await registerUser('ana@correo.com', 'password123', 'Ana')

    expect(create).toHaveBeenCalledTimes(1)
    const createdData = create.mock.calls[0][0].data as { passwordHash: string }
    expect(createdData.passwordHash).not.toBe('password123')
    expect(await bcrypt.compare('password123', createdData.passwordHash)).toBe(true)
    expect(user).toMatchObject({ email: 'ana@correo.com', nombres: 'Ana' })
  })

  it('rechaza el registro si ya existe una cuenta con ese correo', async () => {
    findUnique.mockResolvedValue({ id: 'existing' } as any)

    await expect(registerUser('ana@correo.com', 'password123', 'Ana')).rejects.toThrow(
      'Ya existe una cuenta con ese correo',
    )
    expect(create).not.toHaveBeenCalled()
  })
})

describe('validateCredentials', () => {
  it('devuelve el usuario cuando el password coincide', async () => {
    const passwordHash = await bcrypt.hash('password123', 10)
    findUnique.mockResolvedValue({ id: 'user-1', passwordHash } as any)

    const user = await validateCredentials('ana@correo.com', 'password123')

    expect(user).toMatchObject({ id: 'user-1' })
  })

  it('devuelve null cuando el password no coincide', async () => {
    const passwordHash = await bcrypt.hash('password123', 10)
    findUnique.mockResolvedValue({ id: 'user-1', passwordHash } as any)

    const user = await validateCredentials('ana@correo.com', 'incorrecta')

    expect(user).toBeNull()
  })

  it('devuelve null si la cuenta no tiene password (solo Google)', async () => {
    findUnique.mockResolvedValue({ id: 'user-1', passwordHash: null } as any)

    const user = await validateCredentials('ana@correo.com', 'cualquier-cosa')

    expect(user).toBeNull()
  })

  it('devuelve null si el usuario no existe', async () => {
    findUnique.mockResolvedValue(null)

    const user = await validateCredentials('nadie@correo.com', 'password123')

    expect(user).toBeNull()
  })
})

describe('findOrCreateGoogleUser', () => {
  const profile = {
    id: 'google-123',
    displayName: 'Ana Google',
    emails: [{ value: 'ana@correo.com' }],
    photos: [{ value: 'http://avatar.jpg' }],
  } as unknown as Profile

  it('devuelve el usuario existente si ya está vinculado por googleId', async () => {
    findUnique.mockResolvedValueOnce({ id: 'user-1', googleId: 'google-123' } as any)

    const user = await findOrCreateGoogleUser(profile)

    expect(user).toMatchObject({ id: 'user-1' })
    expect(create).not.toHaveBeenCalled()
    expect(update).not.toHaveBeenCalled()
  })

  it('vincula la cuenta existente por email si el googleId no está registrado', async () => {
    findUnique
      .mockResolvedValueOnce(null) // no hay match por googleId
      .mockResolvedValueOnce({ id: 'user-1', email: 'ana@correo.com' } as any) // sí existe por email
    update.mockResolvedValue({ id: 'user-1', googleId: 'google-123' } as any)

    const user = await findOrCreateGoogleUser(profile)

    expect(update).toHaveBeenCalledWith({ where: { id: 'user-1' }, data: { googleId: 'google-123' } })
    expect(user).toMatchObject({ googleId: 'google-123' })
  })

  it('crea un usuario nuevo si no existe ni por googleId ni por email', async () => {
    findUnique.mockResolvedValueOnce(null).mockResolvedValueOnce(null)
    create.mockImplementation(({ data }: any) => Promise.resolve({ id: 'user-2', ...data }) as any)

    const user = await findOrCreateGoogleUser(profile)

    expect(create).toHaveBeenCalledWith({
      data: {
        email: 'ana@correo.com',
        googleId: 'google-123',
        nombres: 'Ana Google',
        avatarUrl: 'http://avatar.jpg',
      },
    })
    expect(user).toMatchObject({ email: 'ana@correo.com' })
  })

  it('lanza un error si Google no devuelve correo y no hay cuenta previa', async () => {
    findUnique.mockResolvedValueOnce(null)
    const profileWithoutEmail = { id: 'google-999', emails: [] } as unknown as Profile

    await expect(findOrCreateGoogleUser(profileWithoutEmail)).rejects.toThrow(
      'Google no devolvió un correo para esta cuenta',
    )
  })
})

describe('signToken', () => {
  it('firma un JWT verificable con el userId como subject', () => {
    const token = signToken('user-1')
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as { sub: string }

    expect(payload.sub).toBe('user-1')
  })
})
