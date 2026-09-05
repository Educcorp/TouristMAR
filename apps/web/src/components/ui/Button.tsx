import type { ButtonHTMLAttributes } from 'react'
import { cn } from '@/lib/cn'

type ButtonVariant = 'primary' | 'google' | 'ghost'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant
}

const variantStyles: Record<ButtonVariant, string> = {
  primary:
    'bg-[var(--brand-teal)] text-[var(--panel-navy)] hover:bg-[var(--brand-teal-dark)] hover:text-white',
  google: 'bg-white text-slate-800 hover:bg-slate-100',
  ghost: 'bg-white/5 text-white border border-white/10 hover:bg-white/10',
}

export function Button({ variant = 'primary', className, ...props }: ButtonProps) {
  return (
    <button
      className={cn(
        'flex w-full items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-medium transition-colors',
        variantStyles[variant],
        className,
      )}
      {...props}
    />
  )
}
