import {
  FerrisWheel,
  Footprints,
  Mountain,
  Umbrella,
  UtensilsCrossed,
  Waves,
  type LucideIcon,
} from 'lucide-react'
import heroImage from '@/assets/hero-manzanillo.jpg'

const categories: { label: string; icon: LucideIcon }[] = [
  { label: 'Playas', icon: Umbrella },
  { label: 'Senderismo', icon: Footprints },
  { label: 'Restaurantes', icon: UtensilsCrossed },
  { label: 'Miradores', icon: Mountain },
  { label: 'Recreación', icon: FerrisWheel },
]

const stats = [
  { value: '80+', label: 'Lugares' },
  { value: '4.8★', label: 'Valoración media' },
  { value: '360°', label: 'Fotos inmersivas' },
]

function CategoryPill({ icon: Icon, label }: { icon: LucideIcon; label: string }) {
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full border border-white/10 bg-black/30 px-3 py-1.5 text-xs text-white backdrop-blur-sm">
      <Icon className="h-3.5 w-3.5" />
      {label}
    </span>
  )
}

export function HeroPanel() {
  return (
    <div className="relative hidden w-[58%] flex-col lg:flex">
      <img
        src={heroImage}
        alt="Vista aérea de la costa y selva de Manzanillo"
        className="absolute inset-0 h-full w-full object-cover object-left"
      />
      <div className="absolute inset-0 bg-gradient-to-t from-[var(--panel-navy)] via-[var(--panel-navy)]/50 to-black/10" />

      <div className="relative z-10 flex items-center gap-2 p-10">
        <span className="flex h-9 w-9 items-center justify-center rounded-full bg-[var(--brand-teal)]">
          <Waves className="h-5 w-5 text-[var(--panel-navy)]" />
        </span>
        <span className="text-sm font-semibold tracking-[0.2em] text-white">TOURISMAR</span>
      </div>

      <div className="relative z-10 mt-auto space-y-6 p-10 pt-0 lg:p-12 lg:pt-0">
        <p className="text-xs font-semibold tracking-[0.2em] text-[var(--brand-teal)]">
          MANZANILLO · COLIMA
        </p>
        <h1 className="font-serif text-4xl leading-tight text-white lg:text-5xl">
          Descubre el Pacífico
          <br />
          Mexicano
        </h1>
        <p className="max-w-md text-sm text-slate-300 lg:text-base">
          Playas, senderos de hiking, miradores y sabores locales — todo centralizado para que
          explores Manzanillo como nunca antes.
        </p>
        <div className="flex flex-wrap gap-2">
          {categories.map((category) => (
            <CategoryPill key={category.label} {...category} />
          ))}
        </div>
        <div className="flex gap-10 border-t border-white/10 pt-6">
          {stats.map((stat) => (
            <div key={stat.label}>
              <p className="text-xl font-semibold text-white">{stat.value}</p>
              <p className="text-xs text-slate-400">{stat.label}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
