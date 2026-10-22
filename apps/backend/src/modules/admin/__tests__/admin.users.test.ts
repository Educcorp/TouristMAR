import { describe, it, expect, vi, beforeEach } from 'vitest'
import express from 'express'
import request from 'supertest'
import jwt from 'jsonwebtoken'

// "Control de usuarios": el admin corrige nombre y correo de visitantes y
// empresas, pero no de otros admins.

vi.mock('../../../config/prisma', () => ({
  prisma: {
    user: { findUnique: vi.fn(), update: vi.fn() },
  },
}))

import { prisma } from '../../../config/prisma'
import { adminRouter } from '../admin.routes'

const userFind = vi.mocked(prisma.user.findUnique)
const userUpdate = vi.mocked(prisma.user.update)

const ADMIN = 'admin-1'
const TURISTA = 'turista-1'
const OTRO_ADMIN = 'admin-2'
const OTRO = 'otro-1'

const usuarios: Record<string, { rol: string; email: string }> = {
  [ADMIN]: { rol: 'admin', email: 'admin@correo.com' },
  [OTRO_ADMIN]: { rol: 'admin', email: 'otro.admin@correo.com' },
  [TURISTA]: { rol: 'turista', email: 'ana@correo.com' },
  [OTRO]: { rol: 'turista', email: 'tomado@correo.com' },
}

function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api/admin', adminRouter)
  return app
}

const patch = (id: string, body: object) =>
  request(buildApp())
    .patch(`/api/admin/users/${id}`)
    .set('Authorization', `Bearer ${jwt.sign({ sub: ADMIN }, process.env.JWT_SECRET!)}`)
    .send(body)

beforeEach(() => {
  vi.clearAllMocks()
  userFind.mockImplementation(({ where }: any) => {
    const id = where.id ?? Object.keys(usuarios).find((k) => usuarios[k].email === where.email)
    const u = id && usuarios[id]
    return Promise.resolve(u ? { id, nombres: 'X', activo: true, negocios: [], createdAt: new Date(), ...u } : null) as any
  })
  userUpdate.mockImplementation(({ where, data }: any) =>
    Promise.resolve({ id: where.id, activo: true, negocios: [], createdAt: new Date(), ...usuarios[where.id], nombres: 'X', ...data }) as any,
  )
})

describe('PATCH /api/admin/users/:userId', () => {
  it('corrige nombre y correo de un visitante', async () => {
    const res = await patch(TURISTA, { nombres: '  Ana López ', email: 'ana.lopez@correo.com' })
    expect(res.status).toBe(200)
    expect(userUpdate.mock.calls[0][0]).toMatchObject({ data: { nombres: 'Ana López', email: 'ana.lopez@correo.com' } })
    expect(res.body.user).toMatchObject({ name: 'Ana López', email: 'ana.lopez@correo.com' })
  })

  it('rechaza un correo que ya usa otra cuenta', async () => {
    const res = await patch(TURISTA, { email: 'tomado@correo.com' })
    expect(res.status).toBe(409)
    expect(userUpdate).not.toHaveBeenCalled()
  })

  it('no deja editar a otro admin', async () => {
    const res = await patch(OTRO_ADMIN, { nombres: 'Nuevo' })
    expect(res.status).toBe(403)
    expect(userUpdate).not.toHaveBeenCalled()
  })

  it('valida los datos', async () => {
    expect((await patch(TURISTA, {})).status).toBe(400)
    expect((await patch(TURISTA, { email: 'no-es-correo' })).status).toBe(400)
    expect((await patch(TURISTA, { nombres: '   ' })).status).toBe(400)
    expect(userUpdate).not.toHaveBeenCalled()
  })
})
