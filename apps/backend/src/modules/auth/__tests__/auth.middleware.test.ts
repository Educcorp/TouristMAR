import { describe, it, expect, vi } from 'vitest'
import type { Response } from 'express'
import { requireAuth, type AuthedRequest } from '../auth.middleware'
import { signToken } from '../auth.service'

function buildRes() {
  const res: Partial<Response> = {
    status: vi.fn().mockReturnThis(),
    json: vi.fn().mockReturnThis(),
  }
  return res as Response
}

describe('requireAuth', () => {
  it('deja pasar la request y expone userId cuando el token es válido', () => {
    const token = signToken('user-1')
    const req = { headers: { authorization: `Bearer ${token}` } } as AuthedRequest
    const res = buildRes()
    const next = vi.fn()

    requireAuth(req, res, next)

    expect(req.userId).toBe('user-1')
    expect(next).toHaveBeenCalledTimes(1)
    expect(res.status).not.toHaveBeenCalled()
  })

  it('responde 401 si no hay header de autorización', () => {
    const req = { headers: {} } as AuthedRequest
    const res = buildRes()
    const next = vi.fn()

    requireAuth(req, res, next)

    expect(res.status).toHaveBeenCalledWith(401)
    expect(next).not.toHaveBeenCalled()
  })

  it('responde 401 si el token es inválido', () => {
    const req = { headers: { authorization: 'Bearer token-invalido' } } as AuthedRequest
    const res = buildRes()
    const next = vi.fn()

    requireAuth(req, res, next)

    expect(res.status).toHaveBeenCalledWith(401)
    expect(next).not.toHaveBeenCalled()
  })
})
