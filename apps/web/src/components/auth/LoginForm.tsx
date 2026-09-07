import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { ChevronRight, Eye, EyeOff, Lock, Mail, MapPin, User, Waves } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { InputField } from '@/components/ui/InputField'
import { GoogleIcon } from '@/components/icons/GoogleIcon'
import { AuthError, getCurrentUser, googleLoginUrl, login, register, type AuthUser } from '@/services/authService'

const TOKEN_KEY = 'touristmar_token'

type Mode = 'login' | 'register'

export function LoginForm() {
  const [mode, setMode] = useState<Mode>('login')
  const [showPassword, setShowPassword] = useState(false)
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [user, setUser] = useState<AuthUser | null>(null)
  const [isRestoringSession, setIsRestoringSession] = useState(true)

  useEffect(() => {
    const params = new URLSearchParams(window.location.search)
    const tokenFromRedirect = params.get('token')
    const googleError = params.get('error')

    if (tokenFromRedirect || googleError) {
      window.history.replaceState({}, '', window.location.pathname)
    }

    if (googleError) {
      setError('No se pudo iniciar sesión con Google')
    }

    const token = tokenFromRedirect ?? localStorage.getItem(TOKEN_KEY)

    if (!token) {
      setIsRestoringSession(false)
      return
    }

    getCurrentUser(token)
      .then((restoredUser) => {
        localStorage.setItem(TOKEN_KEY, token)
        setUser(restoredUser)
      })
      .catch(() => {
        localStorage.removeItem(TOKEN_KEY)
      })
      .finally(() => setIsRestoringSession(false))
  }, [])

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(null)
    setIsSubmitting(true)

    try {
      const response = mode === 'login' ? await login(email, password) : await register(email, password, name)
      localStorage.setItem(TOKEN_KEY, response.token)
      setUser(response.user)
    } catch (err) {
      setError(err instanceof AuthError ? err.message : 'No se pudo conectar con el servidor')
    } finally {
      setIsSubmitting(false)
    }
  }

  function handleLogout() {
    localStorage.removeItem(TOKEN_KEY)
    setUser(null)
    setEmail('')
    setPassword('')
    setName('')
  }

  function toggleMode() {
    setError(null)
    setMode((current) => (current === 'login' ? 'register' : 'login'))
  }

  if (isRestoringSession) {
    return <div className="flex w-full items-center justify-center px-6 py-12 lg:w-[42%]" />
  }

  if (user) {
    return (
      <div className="flex w-full items-center justify-center px-6 py-12 sm:px-12 lg:w-[42%]">
        <div className="w-full max-w-md space-y-6 text-center">
          <h2 className="font-serif text-3xl text-white">Bienvenido, {user.name}</h2>
          <p className="text-sm text-slate-400">Sesión iniciada como {user.email}</p>
          <Button type="button" variant="ghost" onClick={handleLogout}>
            Cerrar sesión
          </Button>
        </div>
      </div>
    )
  }

  return (
    <div className="flex w-full items-center justify-center px-6 py-12 sm:px-12 lg:w-[42%]">
      <div className="w-full max-w-md space-y-8">
        <div className="flex items-center gap-2 lg:hidden">
          <span className="flex h-9 w-9 items-center justify-center rounded-full bg-[var(--brand-teal)]">
            <Waves className="h-5 w-5 text-[var(--panel-navy)]" />
          </span>
          <span className="text-sm font-semibold tracking-[0.2em] text-white">TOURISMAR</span>
        </div>

        <div>
          <h2 className="font-serif text-3xl text-white">
            {mode === 'login' ? 'Bienvenido de vuelta' : 'Crea tu cuenta'}
          </h2>
          <p className="mt-1 text-sm text-slate-400">
            {mode === 'login'
              ? 'Inicia sesión para seguir explorando Manzanillo'
              : 'Regístrate para guardar tus lugares favoritos'}
          </p>
        </div>

        <form className="space-y-5" onSubmit={handleSubmit}>
          {mode === 'register' && (
            <InputField
              id="name"
              label="Nombre"
              icon={User}
              type="text"
              autoComplete="name"
              placeholder="Tu nombre"
              value={name}
              onChange={(event) => setName(event.target.value)}
              required
            />
          )}

          <InputField
            id="email"
            label="Correo electrónico"
            icon={Mail}
            type="email"
            autoComplete="email"
            placeholder="tu@correo.com"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
          />

          <div>
            <InputField
              id="password"
              label="Contraseña"
              icon={Lock}
              type={showPassword ? 'text' : 'password'}
              autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
              placeholder="••••••••"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
              minLength={8}
              trailing={
                <button
                  type="button"
                  onClick={() => setShowPassword((value) => !value)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300"
                  aria-label={showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña'}
                >
                  {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              }
            />
            {mode === 'login' && (
              <div className="mt-2 flex justify-end">
                <a href="#" className="text-xs text-[var(--brand-teal)] hover:underline">
                  ¿Olvidaste tu contraseña?
                </a>
              </div>
            )}
          </div>

          {error && <p className="text-sm text-red-400">{error}</p>}

          <div className="flex items-center gap-3 text-xs text-slate-500">
            <span className="h-px flex-1 bg-white/10" />
            o continúa con Google
            <span className="h-px flex-1 bg-white/10" />
          </div>

          <Button type="button" variant="google" onClick={() => (window.location.href = googleLoginUrl)}>
            <GoogleIcon />
            Continuar con Google
          </Button>

          <Button type="submit" variant="primary" disabled={isSubmitting}>
            {isSubmitting
              ? mode === 'login'
                ? 'Iniciando sesión...'
                : 'Creando cuenta...'
              : mode === 'login'
                ? 'Iniciar sesión'
                : 'Crear cuenta'}
          </Button>

          <p className="text-center text-sm text-slate-400">
            {mode === 'login' ? (
              <>
                ¿No tienes cuenta?{' '}
                <button
                  type="button"
                  onClick={toggleMode}
                  className="font-medium text-[var(--brand-teal)] hover:underline"
                >
                  Regístrate gratis
                </button>
              </>
            ) : (
              <>
                ¿Ya tienes cuenta?{' '}
                <button
                  type="button"
                  onClick={toggleMode}
                  className="font-medium text-[var(--brand-teal)] hover:underline"
                >
                  Inicia sesión
                </button>
              </>
            )}
          </p>
        </form>

        <button
          type="button"
          className="flex w-full items-center gap-3 rounded-xl border border-white/10 bg-white/5 p-4 text-left transition-colors hover:bg-white/10"
        >
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[var(--brand-teal)]/15 text-[var(--brand-teal)]">
            <MapPin className="h-4 w-4" />
          </span>
          <span className="flex-1">
            <span className="block text-sm font-medium text-white">
              ¿Te gustaría registrar un lugar nuevo?
            </span>
            <span className="block text-xs text-slate-400">
              Propón tu negocio o sitio turístico
            </span>
          </span>
          <ChevronRight className="h-4 w-4 shrink-0 text-slate-400" />
        </button>
      </div>
    </div>
  )
}
