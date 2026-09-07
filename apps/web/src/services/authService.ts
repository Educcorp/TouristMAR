const API_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:4000/api'

export interface AuthUser {
  id: string
  email: string
  name: string
  role: string
  avatarUrl: string | null
}

export interface AuthResponse {
  token: string
  user: AuthUser
}

export class AuthError extends Error {}

async function postCredentials(path: string, body: Record<string, string>): Promise<AuthResponse> {
  const res = await fetch(`${API_URL}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })

  const data = await res.json().catch(() => ({}))

  if (!res.ok) {
    throw new AuthError(data.error ?? 'No se pudo completar la solicitud')
  }

  return data as AuthResponse
}

export function login(email: string, password: string) {
  return postCredentials('/auth/login', { email, password })
}

export function register(email: string, password: string, name: string) {
  return postCredentials('/auth/register', { email, password, name })
}

export const googleLoginUrl = `${API_URL}/auth/google`

export async function getCurrentUser(token: string): Promise<AuthUser> {
  const res = await fetch(`${API_URL}/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
  })

  const data = await res.json().catch(() => ({}))

  if (!res.ok) {
    throw new AuthError(data.error ?? 'No se pudo obtener la sesión')
  }

  return (data as { user: AuthUser }).user
}
