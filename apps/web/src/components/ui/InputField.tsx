import type { InputHTMLAttributes, ReactNode } from 'react'
import type { LucideIcon } from 'lucide-react'
import { cn } from '@/lib/cn'

interface InputFieldProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string
  icon: LucideIcon
  trailing?: ReactNode
}

export function InputField({ label, icon: Icon, trailing, id, className, ...props }: InputFieldProps) {
  return (
    <div className="space-y-2">
      <label htmlFor={id} className="text-sm text-slate-300">
        {label}
      </label>
      <div className="relative">
        <Icon className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-500" />
        <input
          id={id}
          className={cn(
            'w-full rounded-lg border border-white/10 bg-[var(--panel-navy-soft)] py-2.5 pl-10 pr-10 text-sm text-white placeholder:text-slate-500 outline-none focus:border-[var(--brand-teal)] focus:ring-1 focus:ring-[var(--brand-teal)]',
            className,
          )}
          {...props}
        />
        {trailing}
      </div>
    </div>
  )
}
