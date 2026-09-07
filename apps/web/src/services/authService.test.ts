import { describe, it, expect, vi, beforeEach } from 'vitest'
import { login, register, getCurrentUser, AuthError } from './authService'

function mockFetchOnce(ok: boolean, body: unknown) {
  vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValue({
      ok,
      json: async () => body,
    }),
  )
}

beforeEach(() => {
  vi.unstubAllGlobals()
})

describe('login', () => {
  it('hace POST a /auth/login y devuelve token + usuario', async () => {
    const authResponse = {
      token: 'jwt-token',
      user: { id: '1', email: 'ana@correo.com', name: 'Ana', role: 'usuario', avatarUrl: null },
    }
    mockFetchOnce(true, authResponse)

    const result = await login('ana@correo.com', 'password123')

    expect(fetch).toHaveBeenCalledWith(
      expect.stringContaining('/auth/login'),
      expect.objectContaining({
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'ana@correo.com', password: 'password123' }),
      }),
    )
    expect(result).toEqual(authResponse)
  })

  it('lanza AuthError con el mensaje del servidor cuando la respuesta no es ok', async () => {
    mockFetchOnce(false, { error: 'Correo o contraseña incorrectos' })

    await expect(login('ana@correo.com', 'mala')).rejects.toThrow(AuthError)
    await expect(login('ana@correo.com', 'mala')).rejects.toThrow('Correo o contraseña incorrectos')
  })

  it('usa un mensaje genérico si el servidor no manda error ni JSON válido', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        json: async () => {
          throw new Error('not json')
        },
      }),
    )

    await expect(login('ana@correo.com', 'mala')).rejects.toThrow('No se pudo completar la solicitud')
  })
})

describe('register', () => {
  it('hace POST a /auth/register con email, password y name', async () => {
    const authResponse = {
      token: 'jwt-token',
      user: { id: '1', email: 'ana@correo.com', name: 'Ana', role: 'usuario', avatarUrl: null },
    }
    mockFetchOnce(true, authResponse)

    await register('ana@correo.com', 'password123', 'Ana')

    expect(fetch).toHaveBeenCalledWith(
      expect.stringContaining('/auth/register'),
      expect.objectContaining({
        body: JSON.stringify({ email: 'ana@correo.com', password: 'password123', name: 'Ana' }),
      }),
    )
  })
})

describe('getCurrentUser', () => {
  it('manda el bearer token y devuelve el usuario', async () => {
    const user = { id: '1', email: 'ana@correo.com', name: 'Ana', role: 'usuario', avatarUrl: null }
    mockFetchOnce(true, { user })

    const result = await getCurrentUser('jwt-token')

    expect(fetch).toHaveBeenCalledWith(
      expect.stringContaining('/auth/me'),
      expect.objectContaining({ headers: { Authorization: 'Bearer jwt-token' } }),
    )
    expect(result).toEqual(user)
  })

  it('lanza AuthError cuando el token es inválido', async () => {
    mockFetchOnce(false, { error: 'Token inválido o expirado' })

    await expect(getCurrentUser('token-malo')).rejects.toThrow(AuthError)
  })
})
