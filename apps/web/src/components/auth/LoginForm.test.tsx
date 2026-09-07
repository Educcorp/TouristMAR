import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { LoginForm } from './LoginForm'
import { AuthError } from '@/services/authService'

vi.mock('@/services/authService', async () => {
  const actual = await vi.importActual<typeof import('@/services/authService')>('@/services/authService')
  return {
    ...actual,
    login: vi.fn(),
    register: vi.fn(),
    getCurrentUser: vi.fn(),
  }
})

import { login, register } from '@/services/authService'

beforeEach(() => {
  localStorage.clear()
  vi.clearAllMocks()
})

describe('LoginForm', () => {
  it('inicia sesión con email/password y muestra el saludo de bienvenida', async () => {
    vi.mocked(login).mockResolvedValue({
      token: 'jwt-token',
      user: { id: '1', email: 'ana@correo.com', name: 'Ana', role: 'usuario', avatarUrl: null },
    })

    render(<LoginForm />)
    const user = userEvent.setup()

    await user.type(screen.getByLabelText(/correo electrónico/i), 'ana@correo.com')
    await user.type(screen.getByLabelText(/^contraseña$/i), 'password123')
    await user.click(screen.getByRole('button', { name: /iniciar sesión/i }))

    expect(await screen.findByText(/bienvenido, ana/i)).toBeInTheDocument()
    expect(login).toHaveBeenCalledWith('ana@correo.com', 'password123')
    expect(localStorage.getItem('touristmar_token')).toBe('jwt-token')
  })

  it('muestra un error inline cuando el login falla', async () => {
    vi.mocked(login).mockRejectedValue(new AuthError('Correo o contraseña incorrectos'))

    render(<LoginForm />)
    const user = userEvent.setup()

    await user.type(screen.getByLabelText(/correo electrónico/i), 'ana@correo.com')
    await user.type(screen.getByLabelText(/^contraseña$/i), 'incorrecta')
    await user.click(screen.getByRole('button', { name: /iniciar sesión/i }))

    expect(await screen.findByText(/correo o contraseña incorrectos/i)).toBeInTheDocument()
    expect(localStorage.getItem('touristmar_token')).toBeNull()
  })

  it('cambia a modo registro, pide el campo nombre y llama a register', async () => {
    vi.mocked(register).mockResolvedValue({
      token: 'jwt-token-2',
      user: { id: '2', email: 'nueva@correo.com', name: 'Nueva', role: 'usuario', avatarUrl: null },
    })

    render(<LoginForm />)
    const user = userEvent.setup()

    await user.click(screen.getByRole('button', { name: /regístrate gratis/i }))

    expect(screen.getByLabelText(/nombre/i)).toBeInTheDocument()

    await user.type(screen.getByLabelText(/nombre/i), 'Nueva')
    await user.type(screen.getByLabelText(/correo electrónico/i), 'nueva@correo.com')
    await user.type(screen.getByLabelText(/^contraseña$/i), 'password123')
    await user.click(screen.getByRole('button', { name: /crear cuenta/i }))

    expect(register).toHaveBeenCalledWith('nueva@correo.com', 'password123', 'Nueva')
    expect(await screen.findByText(/bienvenido, nueva/i)).toBeInTheDocument()
  })

  it('cierra sesión y borra el token guardado', async () => {
    vi.mocked(login).mockResolvedValue({
      token: 'jwt-token',
      user: { id: '1', email: 'ana@correo.com', name: 'Ana', role: 'usuario', avatarUrl: null },
    })

    render(<LoginForm />)
    const user = userEvent.setup()

    await user.type(screen.getByLabelText(/correo electrónico/i), 'ana@correo.com')
    await user.type(screen.getByLabelText(/^contraseña$/i), 'password123')
    await user.click(screen.getByRole('button', { name: /iniciar sesión/i }))
    await screen.findByText(/bienvenido, ana/i)

    await user.click(screen.getByRole('button', { name: /cerrar sesión/i }))

    expect(screen.getByLabelText(/correo electrónico/i)).toBeInTheDocument()
    expect(localStorage.getItem('touristmar_token')).toBeNull()
  })
})
