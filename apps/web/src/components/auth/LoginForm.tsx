import { useState } from 'react'
import { ChevronRight, Eye, EyeOff, Lock, Mail, MapPin, Waves } from 'lucide-react'
import { Button } from '@/components/ui/Button'
import { InputField } from '@/components/ui/InputField'
import { GoogleIcon } from '@/components/icons/GoogleIcon'

export function LoginForm() {
  const [showPassword, setShowPassword] = useState(false)

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
          <h2 className="font-serif text-3xl text-white">Bienvenido de vuelta</h2>
          <p className="mt-1 text-sm text-slate-400">
            Inicia sesión para seguir explorando Manzanillo
          </p>
        </div>

        <form className="space-y-5" onSubmit={(event) => event.preventDefault()}>
          <InputField
            id="email"
            label="Correo electrónico"
            icon={Mail}
            type="email"
            autoComplete="email"
            placeholder="tu@correo.com"
          />

          <div>
            <InputField
              id="password"
              label="Contraseña"
              icon={Lock}
              type={showPassword ? 'text' : 'password'}
              autoComplete="current-password"
              placeholder="••••••••"
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
            <div className="mt-2 flex justify-end">
              <a href="#" className="text-xs text-[var(--brand-teal)] hover:underline">
                ¿Olvidaste tu contraseña?
              </a>
            </div>
          </div>

          <div className="flex items-center gap-3 text-xs text-slate-500">
            <span className="h-px flex-1 bg-white/10" />
            o continúa con Google
            <span className="h-px flex-1 bg-white/10" />
          </div>

          <Button type="button" variant="google">
            <GoogleIcon />
            Continuar con Google
          </Button>

          <Button type="submit" variant="primary">
            Iniciar sesión
          </Button>

          <p className="text-center text-sm text-slate-400">
            ¿No tienes cuenta?{' '}
            <a href="#" className="font-medium text-[var(--brand-teal)] hover:underline">
              Regístrate gratis
            </a>
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
