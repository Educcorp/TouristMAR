import { describe, it, expect, vi, beforeEach } from 'vitest'
import type { Response } from 'express'

vi.mock('../../../config/prisma', () => ({
  prisma: {
    user: {
      findUnique: vi.fn(),
    },
  },
}))

import { prisma } from '../../../config/prisma'
import { requireAuth, type AuthedRequest } from '../auth.middleware'
import { signToken } from '../auth.service'

const findUnique = vi.mocked(prisma.user.findUnique)

function buildRes() {
  const res: Partial<Response> = {
    status: vi.fn().mockReturnThis(),
    json: vi.fn().mockReturnThis(),
  }
  return res as Response
}

beforeEach(() => {
  vi.clearAllMocks()
})

describe('requireAuth', () => {
  it('deja pasar la request y expone userId cuando el token es válido y la cuenta está activa', async () => {
    findUnique.mockResolvedValue({ id: 'user-1', activo: true, negocios: [] } as any)
    const token = signToken('user-1')
    const req = { headers: { authorization: `Bearer ${token}` } } as AuthedRequest
    const res = buildRes()
    const next = vi.fn()

    await requireAuth(req, res, next)

    expect(req.userId).toBe('user-1')
    expect(next).toHaveBeenCalledTimes(1)
    expect(res.status).not.toHaveBeenCalled()
  })

  it('responde 401 si no hay header de autorización', async () => {
    const req = { headers: {} } as AuthedRequest
    const res = buildRes()
    const next = vi.fn()

    await requireAuth(req, res, next)

    expect(res.status).toHaveBeenCalledWith(401)
    expect(next).not.toHaveBeenCalled()
  })

  it('responde 401 si el token es inválido', async () => {
    const req = { headers: { authorization: 'Bearer token-invalido' } } as AuthedRequest
    const res = buildRes()
    const next = vi.fn()

    await requireAuth(req, res, next)

    expect(res.status).toHaveBeenCalledWith(401)
    expect(next).not.toHaveBeenCalled()
  })

  it('responde 403 si la cuenta fue bloqueada por un administrador', async () => {
    findUnique.mockResolvedValue({ id: 'user-1', activo: false, negocios: [] } as any)
    const token = signToken('user-1')
    const req = { headers: { authorization: `Bearer ${token}` } } as AuthedRequest
    const res = buildRes()
    const next = vi.fn()

    await requireAuth(req, res, next)

    expect(res.status).toHaveBeenCalledWith(403)
    expect(next).not.toHaveBeenCalled()
  })
})
