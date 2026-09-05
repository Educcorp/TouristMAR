import { HeroPanel } from '@/components/auth/HeroPanel'
import { LoginForm } from '@/components/auth/LoginForm'

export function LoginPage() {
  return (
    <div className="flex min-h-screen w-full flex-col bg-[var(--panel-navy)] lg:flex-row">
      <HeroPanel />
      <LoginForm />
    </div>
  )
}
