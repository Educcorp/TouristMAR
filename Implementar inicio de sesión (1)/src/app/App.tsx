import { useState, useRef, type ReactNode } from "react";
import {
  Eye, EyeOff, Mail, Lock, MapPin, ChevronRight, ArrowLeft,
  Waves, X, Bell, Heart, Settings, LogOut, Map, User,
  Camera, Star, Edit3, MessageSquare, Search, Plus, Home,
  BarChart2, Image, Phone, Globe, Clock, CheckCircle, Building2,
  TrendingUp, Users, ThumbsUp, AlertCircle, Shield, ChevronDown,
  Upload, Check, Ban,
} from "lucide-react";

// ─── Types ────────────────────────────────────────────────────────────────────

type LoginType = "visitor" | "business";
type Page =
  | "login"
  | "dashboard" | "profile" | "edit-profile"
  | "b-dashboard" | "b-profile" | "b-edit" | "b-reviews"
  | "a-dashboard" | "a-users" | "a-admins" | "a-businesses" | "a-requests";
type AuthView = "login" | "register" | "forgot" | "forgot-sent";

interface UserProfile {
  name: string; email: string; bio: string; avatar: string;
  visitedPlaces: number; reviews: number;
}
interface BusinessProfile {
  businessName: string; ownerName: string; email: string;
  category: string; description: string; cover: string;
  gallery: string[]; rating: number; totalReviews: number;
  monthlyVisits: number; newReviews: number; favorites: number;
  phone: string; website: string; address: string; hours: string; verified: boolean;
}

// ─── Mock Data ────────────────────────────────────────────────────────────────

const DEFAULT_USER: UserProfile = {
  name: "Ana García Reyes", email: "ana.garcia@gmail.com",
  bio: "Apasionada del mar y la gastronomía local. Explorando Manzanillo un lugar a la vez 🌊",
  avatar: "https://images.unsplash.com/photo-1506863530036-1efeddceb993?w=200&h=200&fit=crop&auto=format",
  visitedPlaces: 12, reviews: 8,
};

const DEFAULT_BUSINESS: BusinessProfile = {
  businessName: "Playa Audiencia Resort & Bar",
  ownerName: "Sofía Mendoza", email: "contacto@playaaudiencia.mx",
  category: "Playa · Bar · Restaurante",
  description: "Un oasis frente al Pacífico. Ofrecemos snorkel, kayak, sillas de playa, bar de mariscos y acceso directo al mar más azul de Manzanillo. Reservaciones y eventos especiales disponibles todo el año.",
  cover: "https://images.unsplash.com/photo-1755493872556-5c29bac85c5c?w=900&h=400&fit=crop&auto=format",
  gallery: [
    "https://images.unsplash.com/photo-1743697706311-120044ecaf22?w=400&h=260&fit=crop&auto=format",
    "https://images.unsplash.com/photo-1787478555928-40f802c6bf7b?w=400&h=260&fit=crop&auto=format",
    "https://images.unsplash.com/photo-1605639671253-f89cefaa8e9d?w=400&h=260&fit=crop&auto=format",
  ],
  rating: 4.9, totalReviews: 124, monthlyVisits: 1243, newReviews: 23, favorites: 89,
  phone: "+52 314 123 4567", website: "playaaudiencia.com.mx",
  address: "Av. de los Cocoteros 42, Manzanillo, Col. 28219",
  hours: "Lun – Dom: 8:00 am – 8:00 pm", verified: true,
};

const SECOND_BUSINESS: BusinessProfile = {
  businessName: "Terraza Vista Mar – Centro",
  ownerName: "Sofía Mendoza", email: "centro@playaaudiencia.mx",
  category: "Bar · Restaurante",
  description: "Nuestra sucursal en el corazón de Manzanillo. Cocina de autor con mariscos frescos y vista panorámica al puerto. Ideal para eventos y reuniones de negocios.",
  cover: "https://images.unsplash.com/photo-1787478555928-40f802c6bf7b?w=900&h=400&fit=crop&auto=format",
  gallery: [
    "https://images.unsplash.com/photo-1501855901885-8b29fa615daf?w=400&h=260&fit=crop&auto=format",
    "https://images.unsplash.com/photo-1770825416402-8474aa899294?w=400&h=260&fit=crop&auto=format",
    "https://images.unsplash.com/photo-1605639671253-f89cefaa8e9d?w=400&h=260&fit=crop&auto=format",
  ],
  rating: 4.7, totalReviews: 67, monthlyVisits: 892, newReviews: 12, favorites: 54,
  phone: "+52 314 234 5678", website: "playaaudiencia.com.mx",
  address: "Av. México 123, Centro, Manzanillo, Col. 28200",
  hours: "Mar – Dom: 12:00 pm – 10:00 pm", verified: true,
};

const MOCK_VISITED = [
  { name: "Playa de Santiago", category: "Playas", rating: 4.8, date: "12 ago 2026", img: "https://images.unsplash.com/photo-1743697706311-120044ecaf22?w=400&h=260&fit=crop&auto=format" },
  { name: "Laguna de Cuyutlán", category: "Recreación", rating: 4.6, date: "3 jul 2026", img: "https://images.unsplash.com/photo-1771636001068-e90df5c47b93?w=400&h=260&fit=crop&auto=format" },
  { name: "Playa Miramar", category: "Playas", rating: 4.7, date: "18 jun 2026", img: "https://images.unsplash.com/photo-1726147417354-cf82fb0548af?w=400&h=260&fit=crop&auto=format" },
];
const MOCK_REVIEWS = [
  { place: "Playa de Santiago", date: "12 ago 2026", rating: 5, text: "Agua cristalina y arena perfecta. Sin duda uno de los mejores rincones de Manzanillo para descansar y desconectarse." },
  { place: "El Bigotes – Mariscos", date: "28 jul 2026", rating: 4, text: "El ceviche estaba delicioso y la vista al mar es espectacular. Ambiente relajado y precios accesibles." },
];
const FEATURED_PLACES = [
  { name: "Playa Audiencia", category: "Playas", rating: 4.9, img: "https://images.unsplash.com/photo-1707006050483-a2eb38b1db92?w=400&h=260&fit=crop&auto=format" },
  { name: "Cerro del Vigía", category: "Miradores", rating: 4.8, img: "https://images.unsplash.com/photo-1501855901885-8b29fa615daf?w=400&h=260&fit=crop&auto=format" },
  { name: "Laguna de Cuyutlán", category: "Recreación", rating: 4.6, img: "https://images.unsplash.com/photo-1605639671253-f89cefaa8e9d?w=400&h=260&fit=crop&auto=format" },
];
const BUSINESS_REVIEWS = [
  { author: "Carlos M.", initials: "CM", rating: 5, date: "8 sep 2026", text: "Un lugar increíble, el agua está perfecta y el servicio es de primera. Sin duda el mejor spot de la ciudad." },
  { author: "Laura P.", initials: "LP", rating: 4, date: "5 sep 2026", text: "Las instalaciones están muy bien mantenidas. El ceviche del bar es delicioso, volvería solo por eso." },
  { author: "Rodrigo T.", initials: "RT", rating: 5, date: "1 sep 2026", text: "Mejor playa de Manzanillo sin duda. Volveré con la familia el próximo puente." },
];

// Admin mock data
const MOCK_ADMIN_USERS = [
  { id: 1, name: "Ana García Reyes", email: "ana.garcia@gmail.com", role: "visitor", status: "active", joined: "12 ene 2026", initials: "AG" },
  { id: 2, name: "Carlos Méndez", email: "carlos.m@gmail.com", role: "visitor", status: "active", joined: "3 mar 2026", initials: "CM" },
  { id: 3, name: "Sofía Mendoza", email: "contacto@playaaudiencia.mx", role: "business", status: "active", joined: "20 abr 2026", initials: "SM" },
  { id: 4, name: "Roberto Vega", email: "roberto.v@gmail.com", role: "visitor", status: "blocked", joined: "7 may 2026", initials: "RV" },
  { id: 5, name: "Laura Ríos", email: "laura.rios@gmail.com", role: "visitor", status: "active", joined: "15 jun 2026", initials: "LR" },
];
const MOCK_ADMIN_REQUESTS_INIT = [
  { id: 1, businessName: "El Bigotes Mariscos", ownerName: "Juan Pérez", email: "juan@bigotes.mx", category: "Restaurante", date: "10 sep 2026" },
  { id: 2, businessName: "Sunset Bar Miramar", ownerName: "Lucía Ramos", email: "lucia@sunset.mx", category: "Bar · Mirador", date: "9 sep 2026" },
  { id: 3, businessName: "Kayak Manzanillo", ownerName: "Pedro Gómez", email: "pedro@kayak.mx", category: "Deportes acuáticos", date: "8 sep 2026" },
];
const MOCK_ADMIN_BIZ = [
  { id: 1, name: "Playa Audiencia Resort & Bar", category: "Playa · Bar", status: "active", rating: 4.9, hasARMarker: true, hasARGeo: false, has360: true },
  { id: 2, name: "El Bigotes Mariscos", category: "Restaurante", status: "active", rating: 4.7, hasARMarker: false, hasARGeo: false, has360: false },
  { id: 3, name: "Terraza Vista Mar", category: "Bar · Restaurante", status: "active", rating: 4.7, hasARMarker: true, hasARGeo: true, has360: false },
  { id: 4, name: "Cerro del Vigía Tours", category: "Mirador · Senderismo", status: "pending", rating: 0, hasARMarker: false, hasARGeo: false, has360: false },
];
const MOCK_ADMINS_LIST = [
  { id: 1, name: "Luis Hernández", email: "luis@tourismar.mx", role: "Administrador", since: "1 ene 2026" },
  { id: 2, name: "María Torres", email: "maria@tourismar.mx", role: "Super Admin", since: "1 ene 2026" },
];

// ─── Shared UI ────────────────────────────────────────────────────────────────

function GoogleIcon() {
  return (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4" />
      <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853" />
      <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05" />
      <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335" />
    </svg>
  );
}
function PasswordInput({ value, onChange, placeholder = "••••••••" }: { value: string; onChange: (v: string) => void; placeholder?: string }) {
  const [show, setShow] = useState(false);
  return (
    <div className="relative">
      <Lock size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
      <input type={show ? "text" : "password"} value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder}
        className="w-full pl-10 pr-11 py-3 rounded-xl bg-input-background border border-border text-foreground placeholder:text-muted-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" />
      <button type="button" onClick={() => setShow((s) => !s)} className="absolute right-3.5 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors">
        {show ? <EyeOff size={15} /> : <Eye size={15} />}
      </button>
    </div>
  );
}
function GoogleButton({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <button type="button" onClick={onClick} className="w-full flex items-center justify-center gap-3 px-4 py-3 rounded-xl border border-border bg-card hover:bg-secondary transition-colors text-foreground text-sm font-medium">
      <GoogleIcon />{label}
    </button>
  );
}
function FieldLabel({ children }: { children: ReactNode }) {
  return <label className="block text-sm text-foreground/80 mb-1.5 font-medium">{children}</label>;
}
function PrimaryButton({ children, onClick, accent }: { children: ReactNode; onClick?: () => void; accent?: boolean }) {
  return (
    <button type="button" onClick={onClick}
      className={`w-full py-3 rounded-xl font-semibold text-sm hover:opacity-90 active:scale-[0.98] transition-all tracking-wide ${accent ? "bg-accent text-accent-foreground" : "bg-primary text-primary-foreground"}`}>
      {children}
    </button>
  );
}
function StarRow({ rating, size = 13 }: { rating: number; size?: number }) {
  return (
    <div className="flex items-center gap-0.5">
      {[1,2,3,4,5].map((i) => <Star key={i} size={size} className={i <= Math.round(rating) ? "text-yellow-400 fill-yellow-400" : "text-muted-foreground/30"} />)}
    </div>
  );
}
function CategoryBadge({ label }: { label: string }) {
  return <span className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-primary/15 text-primary border border-primary/20">{label}</span>;
}

// ─── Visitor: Navbar + Drawer + Shell ─────────────────────────────────────────

function TopNavbar({ user, onAvatarClick, onLogoClick }: { user: UserProfile; onAvatarClick: () => void; onLogoClick: () => void }) {
  return (
    <header className="fixed top-0 left-0 right-0 z-30 flex items-center justify-between px-5 h-[60px] bg-background/90 backdrop-blur-md border-b border-border">
      <button onClick={onLogoClick} className="flex items-center gap-2.5">
        <div className="w-8 h-8 rounded-full bg-primary flex items-center justify-center shadow-md shadow-primary/25"><Waves size={15} className="text-primary-foreground" /></div>
        <span className="text-foreground font-bold text-sm tracking-[0.16em] uppercase hidden sm:block">TourisMAR</span>
      </button>
      <div className="flex items-center gap-2">
        <button className="w-9 h-9 rounded-full flex items-center justify-center text-muted-foreground hover:text-foreground hover:bg-secondary transition-colors relative">
          <Bell size={18} /><span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-accent" />
        </button>
        <button onClick={onAvatarClick} className="w-9 h-9 rounded-full overflow-hidden border-2 border-primary/40 hover:border-primary transition-colors bg-secondary">
          <img src={user.avatar} alt={user.name} className="w-full h-full object-cover" />
        </button>
      </div>
    </header>
  );
}
function SideDrawer({ open, onClose, user, navigate }: { open: boolean; onClose: () => void; user: UserProfile; navigate: (p: Page) => void }) {
  const items = [
    { icon: Home, label: "Inicio", page: "dashboard" as Page },
    { icon: Map, label: "Explorar mapa", page: "dashboard" as Page },
    { icon: Heart, label: "Mis favoritos", page: "dashboard" as Page },
    { icon: User, label: "Mi perfil", page: "profile" as Page, hi: true },
    { icon: Bell, label: "Notificaciones", page: "dashboard" as Page },
    { icon: Settings, label: "Configuración", page: "dashboard" as Page },
  ];
  return (
    <>
      <div onClick={onClose} className={`fixed inset-0 z-40 bg-black/60 backdrop-blur-sm transition-opacity duration-300 ${open ? "opacity-100" : "opacity-0 pointer-events-none"}`} />
      <div className={`fixed top-0 right-0 h-full w-[290px] sm:w-[320px] z-50 flex flex-col bg-card border-l border-border shadow-2xl transition-transform duration-300 ease-in-out ${open ? "translate-x-0" : "translate-x-full"}`}>
        <div className="flex items-center justify-between px-5 py-4 border-b border-border shrink-0">
          <div className="flex items-center gap-2"><div className="w-6 h-6 rounded-full bg-primary flex items-center justify-center"><Waves size={11} className="text-primary-foreground" /></div><span className="text-foreground font-bold text-xs tracking-[0.15em] uppercase">TourisMAR</span></div>
          <button onClick={onClose} className="w-8 h-8 rounded-full flex items-center justify-center text-muted-foreground hover:text-foreground hover:bg-secondary transition-colors"><X size={16} /></button>
        </div>
        <div className="px-5 py-5 border-b border-border shrink-0">
          <div className="flex items-center gap-3.5">
            <img src={user.avatar} alt={user.name} className="w-12 h-12 rounded-full object-cover border-2 border-primary/35 shrink-0" />
            <div className="min-w-0"><p className="text-foreground font-semibold text-sm truncate">{user.name}</p><p className="text-muted-foreground text-xs truncate mt-0.5">{user.email}</p></div>
          </div>
          <div className="flex gap-4 mt-4">
            <div><p className="text-foreground font-bold text-base leading-none">{user.visitedPlaces}</p><p className="text-muted-foreground text-[10px] mt-0.5">Lugares</p></div>
            <div><p className="text-foreground font-bold text-base leading-none">{user.reviews}</p><p className="text-muted-foreground text-[10px] mt-0.5">Reseñas</p></div>
          </div>
        </div>
        <nav className="flex-1 overflow-y-auto px-3 py-3">
          {items.map(({ icon: Icon, label, page, hi }) => (
            <button key={label} onClick={() => { navigate(page); onClose(); }}
              className={`w-full flex items-center gap-3 px-3.5 py-3 rounded-xl text-sm transition-colors mb-1 ${hi ? "bg-primary/10 text-primary font-semibold hover:bg-primary/15" : "text-foreground/75 hover:bg-secondary hover:text-foreground font-medium"}`}>
              <Icon size={17} className={hi ? "text-primary" : "text-muted-foreground"} />{label}
            </button>
          ))}
        </nav>
        <div className="px-3 pb-6 pt-3 border-t border-border shrink-0">
          <button onClick={() => { navigate("login"); onClose(); }} className="w-full flex items-center gap-3 px-3.5 py-3 rounded-xl text-sm text-destructive hover:bg-destructive/10 transition-colors font-medium"><LogOut size={17} />Cerrar sesión</button>
        </div>
      </div>
    </>
  );
}
function AuthShell({ user, navigate, children }: { user: UserProfile; navigate: (p: Page) => void; children: ReactNode }) {
  const [drawerOpen, setDrawerOpen] = useState(false);
  return (
    <div className="min-h-screen bg-background" style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <TopNavbar user={user} onAvatarClick={() => setDrawerOpen(true)} onLogoClick={() => navigate("dashboard")} />
      <SideDrawer open={drawerOpen} onClose={() => setDrawerOpen(false)} user={user} navigate={navigate} />
      <main className="pt-[60px]">{children}</main>
    </div>
  );
}

// ─── Business: Navbar + Drawer + Branch Switcher + Shell ──────────────────────

function BusinessTopNavbar({ business, onAvatarClick, onLogoClick }: { business: BusinessProfile; onAvatarClick: () => void; onLogoClick: () => void }) {
  return (
    <header className="fixed top-0 left-0 right-0 z-30 flex items-center justify-between px-5 h-[60px] bg-background/90 backdrop-blur-md border-b border-border">
      <button onClick={onLogoClick} className="flex items-center gap-2.5">
        <div className="w-8 h-8 rounded-full bg-primary flex items-center justify-center shadow-md shadow-primary/25"><Waves size={15} className="text-primary-foreground" /></div>
        <div className="hidden sm:flex items-center gap-2">
          <span className="text-foreground font-bold text-sm tracking-[0.16em] uppercase">TourisMAR</span>
          <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-accent/15 text-accent border border-accent/25 tracking-wide">EMPRESA</span>
        </div>
      </button>
      <div className="flex items-center gap-2">
        <button className="w-9 h-9 rounded-full flex items-center justify-center text-muted-foreground hover:text-foreground hover:bg-secondary transition-colors relative">
          <Bell size={18} /><span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-accent" />
        </button>
        <button onClick={onAvatarClick} className="w-9 h-9 rounded-full overflow-hidden border-2 border-accent/50 hover:border-accent transition-colors bg-accent/10 flex items-center justify-center">
          <Building2 size={16} className="text-accent" />
        </button>
      </div>
    </header>
  );
}
function BusinessSideDrawer({ open, onClose, business, navigate }: { open: boolean; onClose: () => void; business: BusinessProfile; navigate: (p: Page) => void }) {
  const items = [
    { icon: BarChart2, label: "Dashboard", page: "b-dashboard" as Page },
    { icon: Building2, label: "Mi negocio", page: "b-profile" as Page, hi: true },
    { icon: MessageSquare, label: "Reseñas", page: "b-reviews" as Page },
    { icon: TrendingUp, label: "Estadísticas", page: "b-dashboard" as Page },
    { icon: Settings, label: "Configuración", page: "b-dashboard" as Page },
  ];
  return (
    <>
      <div onClick={onClose} className={`fixed inset-0 z-40 bg-black/60 backdrop-blur-sm transition-opacity duration-300 ${open ? "opacity-100" : "opacity-0 pointer-events-none"}`} />
      <div className={`fixed top-0 right-0 h-full w-[290px] sm:w-[320px] z-50 flex flex-col bg-card border-l border-border shadow-2xl transition-transform duration-300 ease-in-out ${open ? "translate-x-0" : "translate-x-full"}`}>
        <div className="flex items-center justify-between px-5 py-4 border-b border-border shrink-0">
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 rounded-full bg-primary flex items-center justify-center"><Waves size={11} className="text-primary-foreground" /></div>
            <span className="text-foreground font-bold text-xs tracking-[0.15em] uppercase">TourisMAR</span>
            <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-accent/15 text-accent border border-accent/25">EMPRESA</span>
          </div>
          <button onClick={onClose} className="w-8 h-8 rounded-full flex items-center justify-center text-muted-foreground hover:text-foreground hover:bg-secondary transition-colors"><X size={16} /></button>
        </div>
        <div className="px-5 py-5 border-b border-border shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-xl bg-accent/10 border border-accent/25 flex items-center justify-center shrink-0"><Building2 size={20} className="text-accent" /></div>
            <div className="min-w-0">
              <div className="flex items-center gap-1.5">
                <p className="text-foreground font-semibold text-sm truncate">{business.businessName}</p>
                {business.verified && <CheckCircle size={12} className="text-primary shrink-0" />}
              </div>
              <p className="text-muted-foreground text-xs truncate mt-0.5">{business.category}</p>
            </div>
          </div>
          <div className="flex gap-4 mt-4">
            <div><p className="text-foreground font-bold text-base leading-none">{business.rating}★</p><p className="text-muted-foreground text-[10px] mt-0.5">Calificación</p></div>
            <div><p className="text-foreground font-bold text-base leading-none">{business.totalReviews}</p><p className="text-muted-foreground text-[10px] mt-0.5">Reseñas</p></div>
            <div><p className="text-foreground font-bold text-base leading-none">{business.monthlyVisits}</p><p className="text-muted-foreground text-[10px] mt-0.5">Visitas/mes</p></div>
          </div>
        </div>
        <nav className="flex-1 overflow-y-auto px-3 py-3">
          {items.map(({ icon: Icon, label, page, hi }) => (
            <button key={label} onClick={() => { navigate(page); onClose(); }}
              className={`w-full flex items-center gap-3 px-3.5 py-3 rounded-xl text-sm transition-colors mb-1 ${hi ? "bg-accent/10 text-accent font-semibold hover:bg-accent/15" : "text-foreground/75 hover:bg-secondary hover:text-foreground font-medium"}`}>
              <Icon size={17} className={hi ? "text-accent" : "text-muted-foreground"} />{label}
            </button>
          ))}
        </nav>
        <div className="px-3 pb-6 pt-3 border-t border-border shrink-0">
          <button onClick={() => { navigate("login"); onClose(); }} className="w-full flex items-center gap-3 px-3.5 py-3 rounded-xl text-sm text-destructive hover:bg-destructive/10 transition-colors font-medium"><LogOut size={17} />Cerrar sesión</button>
        </div>
      </div>
    </>
  );
}

function BranchSwitcher({ businesses, activeBizIdx, setActiveBizIdx }: {
  businesses: BusinessProfile[]; activeBizIdx: number; setActiveBizIdx: (i: number) => void;
}) {
  const [open, setOpen] = useState(false);
  const current = businesses[activeBizIdx];
  return (
    <div className="border-b border-border bg-card/40 relative z-20">
      <div className="max-w-5xl mx-auto px-4 sm:px-6 py-2.5 flex items-center justify-between">
        <button onClick={() => setOpen((o) => !o)} className="flex items-center gap-2 px-3 py-1.5 rounded-lg hover:bg-secondary transition-colors">
          <Building2 size={13} className="text-accent" />
          <span className="text-foreground font-semibold text-sm">{current.businessName}</span>
          <ChevronDown size={13} className={`text-muted-foreground transition-transform duration-200 ${open ? "rotate-180" : ""}`} />
        </button>
        <span className="text-muted-foreground text-xs">{businesses.length} sucursal{businesses.length !== 1 ? "es" : ""}</span>
        {open && (
          <div className="absolute top-full left-4 mt-1 w-[270px] bg-card border border-border rounded-xl shadow-2xl overflow-hidden">
            {businesses.map((biz, idx) => (
              <button key={idx} onClick={() => { setActiveBizIdx(idx); setOpen(false); }}
                className={`w-full flex items-center gap-3 px-4 py-3 hover:bg-secondary transition-colors text-left ${idx === activeBizIdx ? "bg-accent/8" : ""}`}>
                <div className="w-8 h-8 rounded-lg bg-accent/10 border border-accent/20 flex items-center justify-center shrink-0"><Building2 size={13} className="text-accent" /></div>
                <div className="flex-1 min-w-0">
                  <p className="text-foreground text-sm font-semibold truncate">{biz.businessName}</p>
                  <p className="text-muted-foreground text-[11px] truncate">{biz.category}</p>
                </div>
                {idx === activeBizIdx && <Check size={13} className="text-accent shrink-0" />}
              </button>
            ))}
            <div className="border-t border-border p-2">
              <button onClick={() => { setOpen(false); alert("Formulario para añadir sucursal — próximamente."); }}
                className="w-full flex items-center gap-2 px-3 py-2.5 rounded-lg hover:bg-secondary transition-colors text-primary text-sm font-semibold">
                <Plus size={14} />Añadir sucursal
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function BusinessAuthShell({ businesses, activeBizIdx, setActiveBizIdx, navigate, children }: {
  businesses: BusinessProfile[]; activeBizIdx: number; setActiveBizIdx: (i: number) => void;
  navigate: (p: Page) => void; children: ReactNode;
}) {
  const [drawerOpen, setDrawerOpen] = useState(false);
  const business = businesses[activeBizIdx];
  return (
    <div className="min-h-screen bg-background" style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <BusinessTopNavbar business={business} onAvatarClick={() => setDrawerOpen(true)} onLogoClick={() => navigate("b-dashboard")} />
      <BusinessSideDrawer open={drawerOpen} onClose={() => setDrawerOpen(false)} business={business} navigate={navigate} />
      <main className="pt-[60px]">
        <BranchSwitcher businesses={businesses} activeBizIdx={activeBizIdx} setActiveBizIdx={setActiveBizIdx} />
        {children}
      </main>
    </div>
  );
}

// ─── Admin: Navbar + Drawer + Shell ──────────────────────────────────────────

function AdminTopNavbar({ onMenuClick, onLogoClick }: { onMenuClick: () => void; onLogoClick: () => void }) {
  return (
    <header className="fixed top-0 left-0 right-0 z-30 flex items-center justify-between px-5 h-[60px] bg-background/90 backdrop-blur-md border-b border-border">
      <button onClick={onLogoClick} className="flex items-center gap-2.5">
        <div className="w-8 h-8 rounded-full bg-primary flex items-center justify-center shadow-md shadow-primary/25"><Waves size={15} className="text-primary-foreground" /></div>
        <div className="hidden sm:flex items-center gap-2">
          <span className="text-foreground font-bold text-sm tracking-[0.16em] uppercase">TourisMAR</span>
          <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-violet-400/15 text-violet-400 border border-violet-400/25 tracking-wide">ADMIN</span>
        </div>
      </button>
      <div className="flex items-center gap-2">
        <button className="w-9 h-9 rounded-full flex items-center justify-center text-muted-foreground hover:text-foreground hover:bg-secondary transition-colors relative">
          <Bell size={18} /><span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-yellow-400" />
        </button>
        <button onClick={onMenuClick} className="w-9 h-9 rounded-full border-2 border-violet-400/40 hover:border-violet-400 transition-colors bg-violet-400/10 flex items-center justify-center">
          <Shield size={16} className="text-violet-400" />
        </button>
      </div>
    </header>
  );
}
function AdminSideDrawer({ open, onClose, navigate }: { open: boolean; onClose: () => void; navigate: (p: Page) => void }) {
  const items = [
    { icon: BarChart2, label: "Dashboard", page: "a-dashboard" as Page },
    { icon: AlertCircle, label: "Solicitudes", page: "a-requests" as Page, badge: 3, hi: true },
    { icon: Users, label: "Usuarios", page: "a-users" as Page },
    { icon: Building2, label: "Negocios", page: "a-businesses" as Page },
    { icon: Shield, label: "Administradores", page: "a-admins" as Page },
    { icon: Settings, label: "Configuración", page: "a-dashboard" as Page },
  ];
  return (
    <>
      <div onClick={onClose} className={`fixed inset-0 z-40 bg-black/60 backdrop-blur-sm transition-opacity duration-300 ${open ? "opacity-100" : "opacity-0 pointer-events-none"}`} />
      <div className={`fixed top-0 right-0 h-full w-[290px] sm:w-[320px] z-50 flex flex-col bg-card border-l border-border shadow-2xl transition-transform duration-300 ease-in-out ${open ? "translate-x-0" : "translate-x-full"}`}>
        <div className="flex items-center justify-between px-5 py-4 border-b border-border shrink-0">
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 rounded-full bg-primary flex items-center justify-center"><Waves size={11} className="text-primary-foreground" /></div>
            <span className="text-foreground font-bold text-xs tracking-[0.15em] uppercase">TourisMAR</span>
            <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-violet-400/15 text-violet-400 border border-violet-400/25">ADMIN</span>
          </div>
          <button onClick={onClose} className="w-8 h-8 rounded-full flex items-center justify-center text-muted-foreground hover:text-foreground hover:bg-secondary transition-colors"><X size={16} /></button>
        </div>
        <div className="px-5 py-4 border-b border-border shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-full bg-violet-400/10 border-2 border-violet-400/30 flex items-center justify-center">
              <Shield size={20} className="text-violet-400" />
            </div>
            <div><p className="text-foreground font-semibold text-sm">Panel de administración</p><p className="text-muted-foreground text-xs mt-0.5">Acceso completo al sistema</p></div>
          </div>
        </div>
        <nav className="flex-1 overflow-y-auto px-3 py-3">
          {items.map(({ icon: Icon, label, page, badge, hi }) => (
            <button key={label} onClick={() => { navigate(page); onClose(); }}
              className={`w-full flex items-center gap-3 px-3.5 py-3 rounded-xl text-sm transition-colors mb-1 ${hi ? "bg-yellow-400/10 text-yellow-400 font-semibold hover:bg-yellow-400/15" : "text-foreground/75 hover:bg-secondary hover:text-foreground font-medium"}`}>
              <Icon size={17} className={hi ? "text-yellow-400" : "text-muted-foreground"} />
              {label}
              {badge && <span className="ml-auto w-5 h-5 rounded-full bg-yellow-400 text-background text-[10px] font-bold flex items-center justify-center">{badge}</span>}
            </button>
          ))}
        </nav>
        <div className="px-3 pb-6 pt-3 border-t border-border shrink-0">
          <button onClick={() => { navigate("login"); onClose(); }} className="w-full flex items-center gap-3 px-3.5 py-3 rounded-xl text-sm text-destructive hover:bg-destructive/10 transition-colors font-medium"><LogOut size={17} />Cerrar sesión</button>
        </div>
      </div>
    </>
  );
}
function AdminAuthShell({ navigate, children }: { navigate: (p: Page) => void; children: ReactNode }) {
  const [drawerOpen, setDrawerOpen] = useState(false);
  return (
    <div className="min-h-screen bg-background" style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <AdminTopNavbar onMenuClick={() => setDrawerOpen(true)} onLogoClick={() => navigate("a-dashboard")} />
      <AdminSideDrawer open={drawerOpen} onClose={() => setDrawerOpen(false)} navigate={navigate} />
      <main className="pt-[60px]">{children}</main>
    </div>
  );
}

// ─── Admin: Dashboard ─────────────────────────────────────────────────────────

function AdminDashboardPage({ navigate }: { navigate: (p: Page) => void }) {
  const stats = [
    { icon: Users, value: "1,847", label: "Usuarios registrados", color: "text-primary", bg: "bg-primary/10 border-primary/20" },
    { icon: Building2, value: "23", label: "Negocios activos", color: "text-accent", bg: "bg-accent/10 border-accent/20" },
    { icon: AlertCircle, value: "3", label: "Solicitudes pendientes", color: "text-yellow-400", bg: "bg-yellow-400/10 border-yellow-400/20" },
    { icon: TrendingUp, value: "45.2K", label: "Visitas totales", color: "text-emerald-400", bg: "bg-emerald-400/10 border-emerald-400/20" },
  ];
  const quickNav = [
    { icon: AlertCircle, label: "Solicitudes", page: "a-requests" as Page, color: "text-yellow-400 border-yellow-400/20 bg-yellow-400/10", badge: 3 },
    { icon: Users, label: "Usuarios", page: "a-users" as Page, color: "text-primary border-primary/20 bg-primary/10" },
    { icon: Building2, label: "Negocios", page: "a-businesses" as Page, color: "text-accent border-accent/20 bg-accent/10" },
    { icon: Shield, label: "Admins", page: "a-admins" as Page, color: "text-violet-400 border-violet-400/20 bg-violet-400/10" },
  ];
  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 pb-12">
      {/* Hero */}
      <div className="mt-6 rounded-2xl overflow-hidden relative h-[140px] bg-secondary">
        <div className="absolute inset-0" style={{ background: "linear-gradient(135deg, #2e1065 0%, #081824 65%)" }} />
        <div className="relative z-10 p-6 h-full flex flex-col justify-center">
          <div className="flex items-center gap-2 mb-1"><Shield size={13} className="text-violet-400" /><span className="text-violet-400 text-xs font-bold tracking-widest uppercase">Panel de administración</span></div>
          <h2 className="text-foreground text-xl font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>TourisMAR — Admin</h2>
          <p className="text-muted-foreground text-sm mt-0.5">Gestión central del sistema turístico</p>
        </div>
      </div>
      {/* Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-5">
        {stats.map(({ icon: Icon, value, label, color, bg }) => (
          <div key={label} className={`p-4 rounded-xl border bg-[#07071142] flex flex-col gap-2 ${bg}`}>
            <Icon size={16} className={color} />
            <p className={`text-2xl font-bold leading-none ${color}`}>{value}</p>
            <p className="text-muted-foreground text-[11px] leading-tight">{label}</p>
          </div>
        ))}
      </div>
      {/* Quick nav */}
      <div className="mt-6">
        <h3 className="text-foreground font-semibold text-sm mb-3">Secciones del sistema</h3>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {quickNav.map(({ icon: Icon, label, page, color, badge }) => (
            <button key={label} onClick={() => navigate(page)} className="flex flex-col items-center gap-2.5 p-4 rounded-xl border border-border bg-[#07071142] hover:brightness-110 transition-all relative">
              {badge && <span className="absolute top-2 right-2 w-5 h-5 rounded-full bg-yellow-400 text-background text-[10px] font-bold flex items-center justify-center">{badge}</span>}
              <div className={`w-10 h-10 rounded-full flex items-center justify-center border ${color}`}><Icon size={18} /></div>
              <span className="text-foreground text-xs font-medium">{label}</span>
            </button>
          ))}
        </div>
      </div>
      {/* Pending requests preview */}
      <div className="mt-8">
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-foreground font-semibold text-sm">Solicitudes recientes</h3>
          <button onClick={() => navigate("a-requests")} className="text-primary text-xs font-medium hover:opacity-75">Ver todas</button>
        </div>
        <div className="space-y-3">
          {MOCK_ADMIN_REQUESTS_INIT.slice(0, 2).map((req) => (
            <div key={req.id} className="flex items-center gap-3 p-4 rounded-xl bg-[#07071142] border border-border">
              <div className="w-10 h-10 rounded-xl bg-accent/10 border border-accent/20 flex items-center justify-center shrink-0"><Building2 size={16} className="text-accent" /></div>
              <div className="flex-1 min-w-0">
                <p className="text-foreground font-semibold text-sm truncate">{req.businessName}</p>
                <p className="text-muted-foreground text-xs">{req.ownerName} · {req.category}</p>
              </div>
              <div className="flex gap-2 shrink-0">
                <button className="px-3 py-1.5 rounded-lg bg-emerald-400/10 border border-emerald-400/25 text-emerald-400 text-xs font-semibold hover:bg-emerald-400/20 transition-colors">Aprobar</button>
                <button className="px-3 py-1.5 rounded-lg bg-destructive/10 border border-destructive/25 text-destructive text-xs font-semibold hover:bg-destructive/20 transition-colors">Rechazar</button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── Admin: Users Page ────────────────────────────────────────────────────────

function AdminUsersPage({ navigate }: { navigate: (p: Page) => void }) {
  const [search, setSearch] = useState("");
  const [users, setUsers] = useState(MOCK_ADMIN_USERS);
  const filtered = users.filter((u) => u.name.toLowerCase().includes(search.toLowerCase()) || u.email.toLowerCase().includes(search.toLowerCase()));
  const toggleBlock = (id: number) => setUsers((prev) => prev.map((u) => u.id === id ? { ...u, status: u.status === "blocked" ? "active" : "blocked" } : u));
  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-6 pb-16">
      <div className="flex items-center gap-3 mb-6">
        <button onClick={() => navigate("a-dashboard")} className="flex items-center gap-1.5 text-muted-foreground hover:text-foreground text-sm transition-colors"><ArrowLeft size={15} />Volver</button>
        <h2 className="text-foreground text-xl font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>Gestión de usuarios</h2>
        <span className="px-2 py-0.5 rounded-full bg-primary/10 text-primary border border-primary/25 text-xs font-bold">{users.length}</span>
      </div>
      <div className="relative mb-4">
        <Search size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
        <input type="text" value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Buscar por nombre o correo…"
          className="w-full pl-10 pr-4 py-3 rounded-xl bg-card border border-border text-foreground placeholder:text-muted-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" />
      </div>
      <div className="space-y-2">
        {filtered.map((u) => (
          <div key={u.id} className="flex items-center gap-3 p-4 rounded-xl bg-[#07071142] border border-border">
            <div className="w-10 h-10 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center text-primary text-sm font-bold shrink-0">{u.initials}</div>
            <div className="flex-1 min-w-0">
              <p className="text-foreground font-semibold text-sm truncate">{u.name}</p>
              <p className="text-muted-foreground text-xs truncate">{u.email} · desde {u.joined}</p>
            </div>
            <div className="flex items-center gap-2 shrink-0 flex-wrap justify-end">
              <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${u.role === "business" ? "bg-accent/10 text-accent border-accent/25" : "bg-primary/10 text-primary border-primary/25"}`}>
                {u.role === "business" ? "Empresa" : "Visitante"}
              </span>
              <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${u.status === "blocked" ? "bg-destructive/10 text-destructive border-destructive/25" : "bg-emerald-400/10 text-emerald-400 border-emerald-400/25"}`}>
                {u.status === "blocked" ? "Bloqueado" : "Activo"}
              </span>
              <button onClick={() => toggleBlock(u.id)}
                className={`px-2.5 py-1.5 rounded-lg text-xs font-semibold transition-colors border ${u.status === "blocked" ? "bg-emerald-400/10 border-emerald-400/25 text-emerald-400 hover:bg-emerald-400/20" : "bg-destructive/10 border-destructive/25 text-destructive hover:bg-destructive/20"}`}>
                {u.status === "blocked" ? "Desbloquear" : "Bloquear"}
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Admin: Businesses Page (with AR management) ──────────────────────────────

function AdminBusinessesPage({ navigate }: { navigate: (p: Page) => void }) {
  const [expanded, setExpanded] = useState<number | null>(null);
  const [bizList, setBizList] = useState(MOCK_ADMIN_BIZ);

  const toggleAR = (id: number, field: "hasARMarker" | "hasARGeo" | "has360") => {
    setBizList((prev) => prev.map((b) => b.id === id ? { ...b, [field]: !b[field] } : b));
  };

  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-6 pb-16">
      <div className="flex items-center gap-3 mb-6">
        <button onClick={() => navigate("a-dashboard")} className="flex items-center gap-1.5 text-muted-foreground hover:text-foreground text-sm transition-colors"><ArrowLeft size={15} />Volver</button>
        <h2 className="text-foreground text-xl font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>Gestión de negocios</h2>
        <span className="px-2 py-0.5 rounded-full bg-accent/10 text-accent border border-accent/25 text-xs font-bold">{bizList.length}</span>
      </div>
      <div className="space-y-3">
        {bizList.map((biz) => (
          <div key={biz.id} className="rounded-xl bg-[#07071142] border border-border overflow-hidden">
            <div className="flex items-center gap-3 p-4">
              <div className="w-10 h-10 rounded-xl bg-accent/10 border border-accent/20 flex items-center justify-center shrink-0"><Building2 size={16} className="text-accent" /></div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <p className="text-foreground font-semibold text-sm">{biz.name}</p>
                  <span className={`px-1.5 py-0.5 rounded text-[9px] font-bold border ${biz.status === "pending" ? "bg-yellow-400/10 text-yellow-400 border-yellow-400/25" : "bg-emerald-400/10 text-emerald-400 border-emerald-400/25"}`}>
                    {biz.status === "pending" ? "Pendiente" : "Activo"}
                  </span>
                </div>
                <div className="flex items-center gap-3 mt-0.5">
                  <p className="text-muted-foreground text-xs">{biz.category}</p>
                  {biz.rating > 0 && <span className="text-yellow-400 text-[10px] font-bold">★ {biz.rating}</span>}
                </div>
              </div>
              {/* AR status dots */}
              <div className="flex gap-1.5 shrink-0 mr-2" title="M=Marcador · G=Geo · 360">
                {(["M", "G", "°"] as const).map((key, i) => {
                  const active = i === 0 ? biz.hasARMarker : i === 1 ? biz.hasARGeo : biz.has360;
                  return <span key={key} className={`w-5 h-5 rounded-full flex items-center justify-center text-[9px] font-bold border ${active ? "bg-primary/20 border-primary/40 text-primary" : "bg-muted border-border text-muted-foreground/50"}`}>{key}</span>;
                })}
              </div>
              <button onClick={() => setExpanded(expanded === biz.id ? null : biz.id)} className="text-muted-foreground hover:text-foreground transition-colors">
                <ChevronDown size={16} className={`transition-transform duration-200 ${expanded === biz.id ? "rotate-180" : ""}`} />
              </button>
            </div>

            {expanded === biz.id && (
              <div className="border-t border-border p-4 space-y-2.5">
                <p className="text-muted-foreground text-[10px] font-bold uppercase tracking-widest mb-3">Recursos AR y 360°</p>
                {[
                  { label: "Modelo AR – Marcador", desc: "Archivo 3D para escaneo de QR o marcador físico (.glb / .gltf)", active: biz.hasARMarker, field: "hasARMarker" as const, accept: ".glb,.gltf" },
                  { label: "Modelo AR – Geolocalización", desc: "Modelo para exploración por GPS en exteriores (.glb / .gltf)", active: biz.hasARGeo, field: "hasARGeo" as const, accept: ".glb,.gltf" },
                  { label: "Visor 360°", desc: "Imágenes equirectangulares o video inmersivo del lugar (.jpg / .mp4)", active: biz.has360, field: "has360" as const, accept: ".jpg,.jpeg,.png,.mp4" },
                ].map(({ label, desc, active, field, accept }) => (
                  <div key={label} className="flex items-center gap-4 p-3.5 rounded-xl bg-background/30 border border-border">
                    <div className={`w-9 h-9 rounded-lg flex items-center justify-center border shrink-0 ${active ? "bg-primary/15 border-primary/30 text-primary" : "bg-muted/30 border-border text-muted-foreground"}`}>
                      {active ? <CheckCircle size={16} /> : <Upload size={15} />}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-foreground text-sm font-semibold">{label}</p>
                      <p className="text-muted-foreground text-[11px] mt-0.5 leading-snug">{desc}</p>
                    </div>
                    <label onClick={() => toggleAR(biz.id, field)}
                      className="flex items-center gap-1.5 px-3 py-2 rounded-lg border border-border hover:border-primary/50 hover:bg-primary/5 transition-all cursor-pointer text-xs font-semibold text-foreground/60 hover:text-primary shrink-0">
                      <Upload size={12} />{active ? "Reemplazar" : "Subir"}
                      <input type="file" className="hidden" accept={accept} onChange={() => {}} />
                    </label>
                  </div>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Admin: Requests Page ─────────────────────────────────────────────────────

function AdminRequestsPage({ navigate }: { navigate: (p: Page) => void }) {
  const [requests, setRequests] = useState(MOCK_ADMIN_REQUESTS_INIT);
  const decide = (id: number, action: "approve" | "reject") => {
    setRequests((prev) => prev.filter((r) => r.id !== id));
    alert(action === "approve" ? "Solicitud aprobada. El negocio aparecerá en el mapa." : "Solicitud rechazada.");
  };
  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 py-6 pb-16">
      <div className="flex items-center gap-3 mb-6">
        <button onClick={() => navigate("a-dashboard")} className="flex items-center gap-1.5 text-muted-foreground hover:text-foreground text-sm transition-colors"><ArrowLeft size={15} />Volver</button>
        <h2 className="text-foreground text-xl font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>Solicitudes de negocio</h2>
        {requests.length > 0 && <span className="px-2 py-0.5 rounded-full bg-yellow-400/15 text-yellow-400 border border-yellow-400/25 text-xs font-bold">{requests.length}</span>}
      </div>
      {requests.length === 0 ? (
        <div className="text-center py-20">
          <CheckCircle size={40} className="text-emerald-400 mx-auto mb-3" />
          <p className="text-foreground font-semibold">Sin solicitudes pendientes</p>
          <p className="text-muted-foreground text-sm mt-1">Todas han sido procesadas.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {requests.map((req) => (
            <div key={req.id} className="p-5 rounded-xl bg-[#07071142] border border-border">
              <div className="flex items-start justify-between gap-3 mb-4">
                <div className="flex items-center gap-3">
                  <div className="w-11 h-11 rounded-xl bg-accent/10 border border-accent/20 flex items-center justify-center shrink-0"><Building2 size={18} className="text-accent" /></div>
                  <div>
                    <p className="text-foreground font-bold text-sm">{req.businessName}</p>
                    <p className="text-muted-foreground text-xs mt-0.5">{req.category}</p>
                  </div>
                </div>
                <span className="px-2 py-0.5 rounded-full bg-yellow-400/10 border border-yellow-400/25 text-yellow-400 text-[10px] font-bold shrink-0">Pendiente</span>
              </div>
              <div className="space-y-1.5 mb-4">
                <div className="flex items-center gap-2 text-xs"><User size={12} className="text-muted-foreground shrink-0" /><span className="text-foreground/70">{req.ownerName}</span></div>
                <div className="flex items-center gap-2 text-xs"><Mail size={12} className="text-muted-foreground shrink-0" /><span className="text-foreground/70">{req.email}</span></div>
                <div className="flex items-center gap-2 text-xs"><Clock size={12} className="text-muted-foreground shrink-0" /><span className="text-muted-foreground">Solicitado el {req.date}</span></div>
              </div>
              <div className="flex gap-3">
                <button onClick={() => decide(req.id, "reject")}
                  className="flex-1 py-2.5 rounded-xl border border-destructive/30 text-destructive hover:bg-destructive/10 transition-colors text-sm font-semibold flex items-center justify-center gap-2">
                  <Ban size={14} />Rechazar
                </button>
                <button onClick={() => decide(req.id, "approve")}
                  className="flex-1 py-2.5 rounded-xl bg-emerald-400/10 border border-emerald-400/30 text-emerald-400 hover:bg-emerald-400/20 transition-colors text-sm font-semibold flex items-center justify-center gap-2">
                  <Check size={14} />Aprobar
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// ─── Admin: Admins Page ───────────────────────────────────────────────────────

function AdminAdminsPage({ navigate }: { navigate: (p: Page) => void }) {
  const [showForm, setShowForm] = useState(false);
  const [newAdmin, setNewAdmin] = useState({ name: "", email: "" });
  const [admins, setAdmins] = useState(MOCK_ADMINS_LIST);

  const handleAdd = () => {
    if (!newAdmin.name || !newAdmin.email) return;
    setAdmins((prev) => [...prev, { id: prev.length + 1, name: newAdmin.name, email: newAdmin.email, role: "Administrador", since: "sep 2026" }]);
    setNewAdmin({ name: "", email: "" });
    setShowForm(false);
    alert(`Invitación enviada a ${newAdmin.email}`);
  };

  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 py-6 pb-16">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <button onClick={() => navigate("a-dashboard")} className="flex items-center gap-1.5 text-muted-foreground hover:text-foreground text-sm transition-colors"><ArrowLeft size={15} />Volver</button>
          <h2 className="text-foreground text-xl font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>Administradores</h2>
        </div>
        <button onClick={() => setShowForm((s) => !s)}
          className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-violet-400/10 border border-violet-400/30 text-violet-400 hover:bg-violet-400/20 transition-colors text-sm font-semibold">
          <Plus size={14} />Añadir admin
        </button>
      </div>

      {showForm && (
        <div className="mb-5 p-5 rounded-xl bg-[#07071142] border border-violet-400/25">
          <p className="text-violet-400 text-xs font-bold uppercase tracking-widest mb-4">Nuevo administrador</p>
          <div className="space-y-3 mb-4">
            <div><FieldLabel>Nombre completo</FieldLabel>
              <input type="text" value={newAdmin.name} onChange={(e) => setNewAdmin((d) => ({ ...d, name: e.target.value }))} placeholder="Nombre del administrador"
                className="w-full px-4 py-3 rounded-xl bg-input-background border border-border text-foreground placeholder:text-muted-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" />
            </div>
            <div><FieldLabel>Correo electrónico</FieldLabel>
              <input type="email" value={newAdmin.email} onChange={(e) => setNewAdmin((d) => ({ ...d, email: e.target.value }))} placeholder="admin@tourismar.mx"
                className="w-full px-4 py-3 rounded-xl bg-input-background border border-border text-foreground placeholder:text-muted-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" />
            </div>
          </div>
          <div className="flex gap-3">
            <button onClick={() => setShowForm(false)} className="flex-1 py-2.5 rounded-xl border border-border text-foreground/70 hover:bg-secondary text-sm font-medium transition-colors">Cancelar</button>
            <button onClick={handleAdd} className="flex-1 py-2.5 rounded-xl bg-violet-400/15 border border-violet-400/30 text-violet-400 hover:bg-violet-400/25 transition-colors text-sm font-semibold">Enviar invitación</button>
          </div>
        </div>
      )}

      <div className="space-y-3">
        {admins.map((admin) => (
          <div key={admin.id} className="flex items-center gap-3 p-4 rounded-xl bg-[#07071142] border border-border">
            <div className="w-10 h-10 rounded-full bg-violet-400/10 border border-violet-400/25 flex items-center justify-center shrink-0"><Shield size={16} className="text-violet-400" /></div>
            <div className="flex-1 min-w-0">
              <p className="text-foreground font-semibold text-sm">{admin.name}</p>
              <p className="text-muted-foreground text-xs">{admin.email}</p>
            </div>
            <div className="flex items-center gap-2 shrink-0 flex-wrap justify-end">
              <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${admin.role === "Super Admin" ? "bg-violet-400/15 text-violet-400 border-violet-400/30" : "bg-primary/10 text-primary border-primary/25"}`}>
                {admin.role}
              </span>
              <span className="text-muted-foreground text-[10px]">desde {admin.since}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Business Pages ───────────────────────────────────────────────────────────

function BusinessDashboardPage({ business, navigate }: { business: BusinessProfile; navigate: (p: Page) => void }) {
  const stats = [
    { icon: Users, value: business.monthlyVisits.toLocaleString(), label: "Visitas este mes", color: "text-primary", bg: "bg-primary/10 border-primary/20" },
    { icon: Star, value: `${business.rating}★`, label: "Calificación promedio", color: "text-yellow-400", bg: "bg-yellow-400/10 border-yellow-400/20" },
    { icon: MessageSquare, value: business.newReviews, label: "Reseñas nuevas", color: "text-accent", bg: "bg-accent/10 border-accent/20" },
    { icon: ThumbsUp, value: business.favorites, label: "Marcado favorito", color: "text-emerald-400", bg: "bg-emerald-400/10 border-emerald-400/20" },
  ];
  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 pb-12">
      <div className="mt-6 rounded-2xl overflow-hidden relative h-[160px] sm:h-[180px] bg-secondary">
        <img src={business.cover} alt={business.businessName} className="absolute inset-0 w-full h-full object-cover opacity-50" />
        <div className="absolute inset-0 bg-gradient-to-r from-background/95 via-background/60 to-transparent" />
        <div className="relative z-10 p-6 sm:p-8 h-full flex flex-col justify-center">
          <div className="flex items-center gap-2 mb-1">
            <span className="text-accent text-xs font-bold tracking-widest uppercase">Panel de negocio</span>
            {business.verified && <CheckCircle size={12} className="text-primary" />}
          </div>
          <h2 className="text-foreground text-lg sm:text-xl font-bold leading-tight" style={{ fontFamily: "'Playfair Display', serif" }}>{business.businessName}</h2>
          <p className="text-muted-foreground text-sm mt-1">{business.category}</p>
        </div>
      </div>
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-5">
        {stats.map(({ icon: Icon, value, label, color, bg }) => (
          <div key={label} className={`p-4 rounded-xl border bg-[#07071142] flex flex-col gap-2 ${bg}`}>
            <Icon size={16} className={color} />
            <p className={`text-2xl font-bold leading-none ${color}`}>{value}</p>
            <p className="text-muted-foreground text-[11px] leading-tight">{label}</p>
          </div>
        ))}
      </div>
      <div className="mt-6">
        <h3 className="text-foreground font-semibold text-sm mb-3 tracking-wide">Gestionar negocio</h3>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {[
            { icon: Edit3, label: "Editar información", page: "b-edit" as Page, iconClass: "bg-primary/10 border-primary/20 text-primary" },
            { icon: Image, label: "Gestionar fotos", page: "b-edit" as Page, iconClass: "bg-accent/10 border-accent/20 text-accent" },
            { icon: MessageSquare, label: "Ver reseñas", page: "b-reviews" as Page, iconClass: "bg-yellow-400/10 border-yellow-400/20 text-yellow-400" },
            { icon: TrendingUp, label: "Estadísticas", page: "b-dashboard" as Page, iconClass: "bg-emerald-400/10 border-emerald-400/20 text-emerald-400" },
          ].map(({ icon: Icon, label, page, iconClass }) => (
            <button key={label} onClick={() => navigate(page)} className="flex flex-col items-center gap-2.5 p-4 rounded-xl border border-border bg-[#07071142] hover:brightness-110 transition-all">
              <div className={`w-10 h-10 rounded-full flex items-center justify-center border ${iconClass}`}><Icon size={18} /></div>
              <span className="text-foreground text-xs font-medium text-center leading-tight">{label}</span>
            </button>
          ))}
        </div>
      </div>
      <div className="mt-8">
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-foreground font-semibold text-sm">Reseñas recientes</h3>
          <button onClick={() => navigate("b-reviews")} className="text-primary text-xs hover:opacity-75 font-medium">Ver todas</button>
        </div>
        <div className="space-y-3">
          {BUSINESS_REVIEWS.slice(0, 2).map((r) => (
            <div key={r.author} className="flex gap-3 p-4 rounded-xl border border-border bg-[#07071142]">
              <div className="w-9 h-9 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center shrink-0 text-primary text-xs font-bold">{r.initials}</div>
              <div className="min-w-0">
                <div className="flex items-center justify-between gap-2">
                  <p className="text-foreground font-semibold text-sm">{r.author}</p>
                  <div className="flex items-center gap-1.5 shrink-0"><StarRow rating={r.rating} size={11} /><span className="text-muted-foreground text-[10px]">{r.date}</span></div>
                </div>
                <p className="text-foreground/70 text-sm mt-1 leading-relaxed line-clamp-2">{r.text}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
      <div className="mt-5 p-4 rounded-xl border border-accent/25 bg-accent/5 flex gap-3 items-start">
        <AlertCircle size={16} className="text-accent shrink-0 mt-0.5" />
        <div>
          <p className="text-foreground text-sm font-semibold">Completa tu perfil de negocio</p>
          <p className="text-muted-foreground text-xs mt-0.5">Agrega horarios detallados y al menos 5 fotos para aparecer destacado en el mapa.</p>
          <button onClick={() => navigate("b-edit")} className="text-accent text-xs font-semibold mt-2 hover:opacity-75 transition-opacity">Completar ahora →</button>
        </div>
      </div>
    </div>
  );
}

function BusinessProfilePage({ business, navigate }: { business: BusinessProfile; navigate: (p: Page) => void }) {
  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <div className="relative h-[200px] sm:h-[240px] bg-secondary overflow-hidden">
        <img src={business.cover} alt={business.businessName} className="w-full h-full object-cover" />
        <div className="absolute inset-0 bg-gradient-to-t from-background via-background/20 to-transparent" />
      </div>
      <div className="max-w-2xl mx-auto px-4 sm:px-6 pb-16">
        <div className="flex items-end gap-4 -mt-10 mb-5 relative z-10">
          <div className="w-20 h-20 rounded-2xl bg-card border-2 border-accent/30 flex items-center justify-center shadow-xl shrink-0"><Building2 size={28} className="text-accent" /></div>
          <div className="pb-1">
            <div className="flex items-center gap-2 flex-wrap">
              <h2 className="text-foreground text-xl font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>{business.businessName}</h2>
              {business.verified && <span className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-primary/15 border border-primary/25 text-primary text-[10px] font-bold"><CheckCircle size={10} />Verificado</span>}
            </div>
            <p className="text-muted-foreground text-xs mt-0.5">{business.category}</p>
          </div>
        </div>
        <div className="flex items-center justify-between gap-3 mb-5">
          <div className="flex items-center gap-2"><StarRow rating={business.rating} size={14} /><span className="text-foreground font-bold text-sm">{business.rating}</span><span className="text-muted-foreground text-xs">({business.totalReviews} reseñas)</span></div>
          <button onClick={() => navigate("b-edit")} className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl border border-accent/40 text-accent hover:bg-accent/8 transition-colors text-sm font-semibold"><Edit3 size={13} />Editar</button>
        </div>
        <div className="p-4 rounded-xl bg-card border border-border mb-5">
          <p className="text-muted-foreground text-[10px] font-semibold uppercase tracking-widest mb-2">Descripción</p>
          <p className="text-foreground/85 text-sm leading-relaxed">{business.description}</p>
        </div>
        <div className="p-4 rounded-xl bg-card border border-border mb-5 space-y-3">
          <p className="text-muted-foreground text-[10px] font-semibold uppercase tracking-widest mb-1">Información de contacto</p>
          {[{ icon: MapPin, value: business.address }, { icon: Phone, value: business.phone }, { icon: Globe, value: business.website }, { icon: Clock, value: business.hours }].map(({ icon: Icon, value }) => (
            <div key={value} className="flex items-start gap-3"><Icon size={14} className="text-primary mt-0.5 shrink-0" /><p className="text-foreground/80 text-sm">{value}</p></div>
          ))}
        </div>
        <div className="mb-5">
          <div className="flex items-center justify-between mb-3">
            <p className="text-foreground font-semibold text-sm">Galería de fotos</p>
            <button onClick={() => navigate("b-edit")} className="text-accent text-xs font-medium hover:opacity-75">Gestionar</button>
          </div>
          <div className="grid grid-cols-3 gap-2">
            {business.gallery.map((img, i) => (
              <div key={i} className="aspect-square rounded-xl overflow-hidden bg-secondary group cursor-pointer">
                <img src={img} alt={`Foto ${i + 1}`} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
              </div>
            ))}
            <button onClick={() => navigate("b-edit")} className="aspect-square rounded-xl border-2 border-dashed border-border hover:border-accent/50 flex flex-col items-center justify-center gap-1 text-muted-foreground hover:text-accent transition-colors">
              <Plus size={18} /><span className="text-[10px] font-medium">Agregar</span>
            </button>
          </div>
        </div>
        <div>
          <div className="flex items-center justify-between mb-3">
            <p className="text-foreground font-semibold text-sm">Últimas reseñas</p>
            <button onClick={() => navigate("b-reviews")} className="text-primary text-xs font-medium hover:opacity-75">Ver todas</button>
          </div>
          <div className="space-y-3">
            {BUSINESS_REVIEWS.slice(0, 2).map((r) => (
              <div key={r.author} className="p-4 rounded-xl bg-card border border-border">
                <div className="flex items-center justify-between gap-2 mb-2">
                  <div className="flex items-center gap-2.5">
                    <div className="w-8 h-8 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center text-primary text-xs font-bold">{r.initials}</div>
                    <div><p className="text-foreground font-semibold text-xs">{r.author}</p><p className="text-muted-foreground text-[10px]">{r.date}</p></div>
                  </div>
                  <StarRow rating={r.rating} size={11} />
                </div>
                <p className="text-foreground/75 text-sm leading-relaxed">{r.text}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function BusinessReviewsPage({ business, navigate }: { business: BusinessProfile; navigate: (p: Page) => void }) {
  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 py-6 pb-16" style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <div className="flex items-center gap-3 mb-6">
        <button onClick={() => navigate("b-dashboard")} className="flex items-center gap-1.5 text-muted-foreground hover:text-foreground text-sm transition-colors"><ArrowLeft size={15} />Volver</button>
        <h2 className="text-foreground text-xl font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>Reseñas de clientes</h2>
      </div>
      <div className="flex items-center gap-5 p-4 rounded-xl bg-[#07071142] border border-border mb-6">
        <div className="text-center">
          <p className="text-foreground text-4xl font-bold">{business.rating}</p>
          <StarRow rating={business.rating} size={14} />
          <p className="text-muted-foreground text-xs mt-1">{business.totalReviews} reseñas</p>
        </div>
        <div className="flex-1 space-y-1.5">
          {[5, 4, 3, 2, 1].map((s) => {
            const pct = s === 5 ? 72 : s === 4 ? 18 : s === 3 ? 6 : s === 2 ? 3 : 1;
            return (
              <div key={s} className="flex items-center gap-2">
                <span className="text-muted-foreground text-[11px] w-3">{s}</span>
                <Star size={10} className="text-yellow-400 fill-yellow-400 shrink-0" />
                <div className="flex-1 h-1.5 rounded-full bg-secondary overflow-hidden"><div className="h-full rounded-full bg-yellow-400" style={{ width: `${pct}%` }} /></div>
                <span className="text-muted-foreground text-[11px] w-5 text-right">{pct}%</span>
              </div>
            );
          })}
        </div>
      </div>
      <div className="space-y-3">
        {BUSINESS_REVIEWS.map((r) => (
          <div key={r.author} className="p-4 rounded-xl bg-[#07071142] border border-border">
            <div className="flex items-center justify-between gap-2 mb-2">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center text-primary text-xs font-bold">{r.initials}</div>
                <div><p className="text-foreground font-semibold text-sm">{r.author}</p><p className="text-muted-foreground text-xs">{r.date}</p></div>
              </div>
              <StarRow rating={r.rating} size={13} />
            </div>
            <p className="text-foreground/75 text-sm leading-relaxed">{r.text}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

function BusinessEditPage({ business, setBusiness, navigate }: { business: BusinessProfile; setBusiness: (b: BusinessProfile) => void; navigate: (p: Page) => void }) {
  const [draft, setDraft] = useState({ businessName: business.businessName, description: business.description, category: business.category, phone: business.phone, website: business.website, address: business.address, hours: business.hours, cover: business.cover });
  const fileRef = useRef<HTMLInputElement>(null);
  const handleCoverChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]; if (!file) return;
    const reader = new FileReader(); reader.onloadend = () => setDraft((d) => ({ ...d, cover: reader.result as string })); reader.readAsDataURL(file);
  };
  return (
    <div className="max-w-lg mx-auto px-4 sm:px-6 py-6 pb-16" style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <button onClick={() => navigate("b-profile")} className="flex items-center gap-1.5 text-muted-foreground hover:text-foreground text-sm mb-6 transition-colors"><ArrowLeft size={15} />Volver a mi negocio</button>
      <h2 className="text-foreground text-2xl font-bold mb-1" style={{ fontFamily: "'Playfair Display', serif" }}>Editar negocio</h2>
      <p className="text-muted-foreground text-sm mb-8">Actualiza la información visible a los visitantes en el mapa.</p>
      <div className="relative h-[140px] rounded-2xl overflow-hidden bg-secondary mb-6 group cursor-pointer" onClick={() => fileRef.current?.click()}>
        <img src={draft.cover} alt="Portada" className="w-full h-full object-cover" />
        <div className="absolute inset-0 bg-black/40 flex flex-col items-center justify-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity"><Camera size={22} className="text-white" /><span className="text-white text-xs font-semibold">Cambiar foto de portada</span></div>
      </div>
      <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={handleCoverChange} />
      <div className="space-y-5">
        <div><FieldLabel>Nombre del negocio</FieldLabel>
          <input type="text" value={draft.businessName} onChange={(e) => setDraft((d) => ({ ...d, businessName: e.target.value }))}
            className="w-full px-4 py-3 rounded-xl bg-input-background border border-border text-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" /></div>
        <div><FieldLabel>Categoría</FieldLabel>
          <input type="text" value={draft.category} onChange={(e) => setDraft((d) => ({ ...d, category: e.target.value }))} placeholder="Ej. Playa · Restaurante · Bar"
            className="w-full px-4 py-3 rounded-xl bg-input-background border border-border text-foreground placeholder:text-muted-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" /></div>
        <div><FieldLabel>Descripción</FieldLabel>
          <textarea value={draft.description} onChange={(e) => setDraft((d) => ({ ...d, description: e.target.value }))} rows={4} maxLength={350}
            className="w-full px-4 py-3 rounded-xl bg-input-background border border-border text-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors resize-none" />
          <p className="text-muted-foreground text-[11px] mt-1 text-right">{draft.description.length}/350</p></div>
        <div className="border-t border-border pt-5">
          <p className="text-muted-foreground text-[10px] font-semibold uppercase tracking-widest mb-4">Información de contacto</p>
          <div className="space-y-4">
            {[
              { icon: MapPin, key: "address", label: "Dirección", placeholder: "Calle, número, colonia…" },
              { icon: Phone, key: "phone", label: "Teléfono", placeholder: "+52 314 000 0000" },
              { icon: Globe, key: "website", label: "Sitio web", placeholder: "miweb.com.mx" },
              { icon: Clock, key: "hours", label: "Horario", placeholder: "Lun – Dom: 9:00 am – 6:00 pm" },
            ].map(({ icon: Icon, key, label, placeholder }) => (
              <div key={key}><FieldLabel>{label}</FieldLabel>
                <div className="relative">
                  <Icon size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
                  <input type="text" value={(draft as Record<string, string>)[key]} onChange={(e) => setDraft((d) => ({ ...d, [key]: e.target.value }))} placeholder={placeholder}
                    className="w-full pl-10 pr-4 py-3 rounded-xl bg-input-background border border-border text-foreground placeholder:text-muted-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" />
                </div>
              </div>
            ))}
          </div>
        </div>
        <div className="p-3.5 rounded-xl bg-secondary border border-border flex gap-3 items-start">
          <AlertCircle size={14} className="text-accent shrink-0 mt-0.5" />
          <p className="text-muted-foreground text-xs leading-relaxed">Las <strong className="text-foreground/70">fotos 360°</strong> y la <strong className="text-foreground/70">tarjeta AR</strong> son generadas por el administrador de TourisMAR tras su visita al lugar.</p>
        </div>
      </div>
      <div className="mt-7 flex gap-3">
        <button onClick={() => navigate("b-profile")} className="flex-1 py-3 rounded-xl border border-border text-foreground/70 hover:text-foreground hover:bg-secondary transition-colors text-sm font-medium">Cancelar</button>
        <button onClick={() => { setBusiness({ ...business, ...draft }); navigate("b-profile"); }}
          className="flex-1 py-3 rounded-xl bg-accent text-accent-foreground font-semibold text-sm hover:opacity-90 active:scale-[0.98] transition-all">Guardar cambios</button>
      </div>
    </div>
  );
}

// ─── Visitor Pages ────────────────────────────────────────────────────────────

function DashboardPage({ user, navigate }: { user: UserProfile; navigate: (p: Page) => void }) {
  const hour = new Date().getHours();
  const greeting = hour < 12 ? "Buenos días" : hour < 18 ? "Buenas tardes" : "Buenas noches";
  const firstName = user.name.split(" ")[0];
  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 pb-12">
      <div className="mt-6 rounded-2xl overflow-hidden relative h-[160px] sm:h-[180px] bg-secondary">
        <img src="https://images.unsplash.com/photo-1771636001068-e90df5c47b93?w=1000&h=400&fit=crop&auto=format" alt="Manzanillo" className="absolute inset-0 w-full h-full object-cover opacity-40" />
        <div className="absolute inset-0 bg-gradient-to-r from-background/90 via-background/50 to-transparent" />
        <div className="relative z-10 p-6 sm:p-8 h-full flex flex-col justify-center">
          <p className="text-primary text-xs font-semibold tracking-widest uppercase mb-1">Manzanillo · Colima</p>
          <h2 className="text-foreground text-xl sm:text-2xl font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>{greeting}, {firstName} ☀️</h2>
          <p className="text-muted-foreground text-sm mt-1">¿Qué vas a explorar hoy?</p>
        </div>
      </div>
      <div className="mt-5 relative">
        <Search size={16} className="absolute left-4 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
        <input type="text" placeholder="Buscar playas, restaurantes, miradores…" className="w-full pl-11 pr-4 py-3 rounded-xl bg-card border border-border text-foreground placeholder:text-muted-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" />
      </div>
      <div className="mt-6">
        <h3 className="text-foreground font-semibold text-sm mb-3 tracking-wide">Acciones rápidas</h3>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {[
            { icon: Map, label: "Explorar mapa", color: "bg-primary/10 text-primary border-primary/20" },
            { icon: Heart, label: "Mis favoritos", color: "bg-accent/10 text-accent border-accent/20" },
            { icon: Plus, label: "Proponer lugar", color: "bg-emerald-400/10 text-emerald-400 border-emerald-400/20" },
            { icon: Bell, label: "Notificaciones", color: "bg-yellow-400/10 text-yellow-400 border-yellow-400/20" },
          ].map(({ icon: Icon, label, color }) => (
            <button key={label} className={`flex flex-col items-center gap-2.5 p-4 rounded-xl border bg-card hover:brightness-110 transition-all ${color}`}>
              <div className={`w-10 h-10 rounded-full flex items-center justify-center border ${color}`}><Icon size={18} /></div>
              <span className="text-foreground text-xs font-medium text-center leading-tight">{label}</span>
            </button>
          ))}
        </div>
      </div>
      <div className="mt-8">
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-foreground font-semibold text-sm tracking-wide">Lugares destacados</h3>
          <button className="text-primary text-xs hover:opacity-75 transition-opacity font-medium">Ver todos</button>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          {FEATURED_PLACES.map((place) => (
            <div key={place.name} className="rounded-2xl overflow-hidden bg-card border border-border group cursor-pointer hover:border-primary/30 transition-colors">
              <div className="h-[150px] relative bg-secondary overflow-hidden">
                <img src={place.img} alt={place.name} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
                <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
                <div className="absolute bottom-2.5 left-3"><CategoryBadge label={place.category} /></div>
              </div>
              <div className="px-3.5 py-3">
                <p className="text-foreground font-semibold text-sm">{place.name}</p>
                <div className="flex items-center gap-1.5 mt-1"><StarRow rating={place.rating} size={11} /><span className="text-muted-foreground text-[11px]">{place.rating}</span></div>
              </div>
            </div>
          ))}
        </div>
      </div>
      <button onClick={() => alert("Formulario para registrar un lugar nuevo — próximamente.")}
        className="mt-6 w-full flex items-center justify-between px-4 py-4 rounded-xl border border-border hover:border-primary/40 hover:bg-primary/5 transition-all group">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-lg bg-primary/10 flex items-center justify-center shrink-0"><MapPin size={15} className="text-primary" /></div>
          <div className="text-left"><p className="text-foreground text-sm font-semibold">¿Te gustaría registrar un lugar nuevo?</p><p className="text-muted-foreground text-xs mt-0.5">Propón tu negocio o sitio turístico</p></div>
        </div>
        <ChevronRight size={15} className="text-muted-foreground group-hover:text-primary transition-colors shrink-0 ml-2" />
      </button>
    </div>
  );
}

function ProfilePage({ user, navigate }: { user: UserProfile; navigate: (p: Page) => void }) {
  return (
    <div style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <div className="relative bg-secondary overflow-hidden">
        <div className="absolute inset-0 opacity-25" style={{ background: "linear-gradient(135deg, #00c2cb 0%, #0d2236 60%, #ff7a45 100%)" }} />
        <div className="absolute inset-0 bg-gradient-to-b from-transparent to-background/80" />
        <div className="relative z-10 flex flex-col items-center pt-10 pb-6 px-6">
          <img src={user.avatar} alt={user.name} className="w-24 h-24 rounded-full object-cover border-4 border-primary/40 shadow-xl shadow-primary/20" />
          <h2 className="text-foreground text-2xl font-bold mt-4 text-center" style={{ fontFamily: "'Playfair Display', serif" }}>{user.name}</h2>
          <p className="text-muted-foreground text-xs mt-1">{user.email}</p>
        </div>
      </div>
      <div className="max-w-2xl mx-auto px-4 sm:px-6 pb-16">
        <div className="flex divide-x divide-border border border-border rounded-2xl mt-5 overflow-hidden bg-card">
          {[{ value: user.visitedPlaces, label: "Lugares visitados", icon: MapPin }, { value: user.reviews, label: "Reseñas escritas", icon: MessageSquare }, { value: "4.7★", label: "Valoración media", icon: Star }].map(({ value, label, icon: Icon }) => (
            <div key={label} className="flex-1 flex flex-col items-center py-4 gap-1">
              <Icon size={14} className="text-primary mb-0.5" />
              <p className="text-foreground font-bold text-lg leading-none">{value}</p>
              <p className="text-muted-foreground text-[10px] text-center px-1 leading-tight">{label}</p>
            </div>
          ))}
        </div>
        {user.bio && <div className="mt-5 p-4 rounded-xl bg-card border border-border"><p className="text-muted-foreground text-[10px] font-semibold uppercase tracking-widest mb-2">Sobre mí</p><p className="text-foreground/85 text-sm leading-relaxed">{user.bio}</p></div>}
        <button onClick={() => navigate("edit-profile")} className="mt-4 w-full flex items-center justify-center gap-2 py-3 rounded-xl border border-primary/40 text-primary hover:bg-primary/8 transition-colors font-semibold text-sm"><Edit3 size={15} />Editar perfil</button>
        <div className="mt-8">
          <div className="flex items-center justify-between mb-3"><h3 className="text-foreground font-semibold text-sm" style={{ fontFamily: "'Playfair Display', serif" }}>Lugares visitados</h3><span className="text-muted-foreground text-xs">{user.visitedPlaces} en total</span></div>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            {MOCK_VISITED.map((place) => (
              <div key={place.name} className="rounded-xl overflow-hidden bg-card border border-border group cursor-pointer hover:border-primary/30 transition-colors">
                <div className="h-[110px] relative bg-secondary overflow-hidden">
                  <img src={place.img} alt={place.name} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent" />
                  <div className="absolute bottom-2 left-2.5"><CategoryBadge label={place.category} /></div>
                </div>
                <div className="px-3 py-2.5">
                  <p className="text-foreground font-semibold text-xs truncate">{place.name}</p>
                  <div className="flex items-center justify-between mt-1">
                    <div className="flex items-center gap-1"><StarRow rating={place.rating} size={10} /><span className="text-muted-foreground text-[10px]">{place.rating}</span></div>
                    <span className="text-muted-foreground text-[10px]">{place.date}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
        <div className="mt-8">
          <div className="flex items-center justify-between mb-3"><h3 className="text-foreground font-semibold text-sm" style={{ fontFamily: "'Playfair Display', serif" }}>Mis reseñas</h3><span className="text-muted-foreground text-xs">{user.reviews} en total</span></div>
          <div className="space-y-3">
            {MOCK_REVIEWS.map((rev) => (
              <div key={rev.place} className="p-4 rounded-xl bg-card border border-border">
                <div className="flex items-start justify-between gap-3 mb-2"><div><p className="text-foreground font-semibold text-sm">{rev.place}</p><p className="text-muted-foreground text-xs mt-0.5">{rev.date}</p></div><StarRow rating={rev.rating} size={12} /></div>
                <p className="text-foreground/75 text-sm leading-relaxed">{rev.text}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function EditProfilePage({ user, setUser, navigate }: { user: UserProfile; setUser: (u: UserProfile) => void; navigate: (p: Page) => void }) {
  const [draft, setDraft] = useState({ name: user.name, bio: user.bio, avatar: user.avatar });
  const fileRef = useRef<HTMLInputElement>(null);
  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]; if (!file) return;
    const reader = new FileReader(); reader.onloadend = () => setDraft((d) => ({ ...d, avatar: reader.result as string })); reader.readAsDataURL(file);
  };
  return (
    <div className="max-w-lg mx-auto px-4 sm:px-6 py-6 pb-16" style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      <button onClick={() => navigate("profile")} className="flex items-center gap-1.5 text-muted-foreground hover:text-foreground text-sm mb-6 transition-colors"><ArrowLeft size={15} />Volver a mi perfil</button>
      <h2 className="text-foreground text-2xl font-bold mb-1" style={{ fontFamily: "'Playfair Display', serif" }}>Editar perfil</h2>
      <p className="text-muted-foreground text-sm mb-8">Actualiza tu foto, nombre y descripción personal.</p>
      <div className="flex flex-col items-center mb-8">
        <div className="relative group cursor-pointer" onClick={() => fileRef.current?.click()}>
          <img src={draft.avatar} alt="Foto de perfil" className="w-24 h-24 rounded-full object-cover border-4 border-primary/35 shadow-lg shadow-primary/15" />
          <div className="absolute inset-0 rounded-full bg-black/40 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"><Camera size={22} className="text-white" /></div>
        </div>
        <button type="button" onClick={() => fileRef.current?.click()} className="mt-3 text-primary text-xs font-semibold hover:opacity-75 flex items-center gap-1"><Camera size={12} />Cambiar foto</button>
        <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={handleFileChange} />
      </div>
      <div className="space-y-5">
        <div><FieldLabel>Nombre completo</FieldLabel>
          <input type="text" value={draft.name} onChange={(e) => setDraft((d) => ({ ...d, name: e.target.value }))}
            className="w-full px-4 py-3 rounded-xl bg-input-background border border-border text-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" /></div>
        <div><FieldLabel>Descripción personal</FieldLabel>
          <textarea value={draft.bio} onChange={(e) => setDraft((d) => ({ ...d, bio: e.target.value }))} rows={4} maxLength={200} placeholder="Cuéntanos un poco sobre ti…"
            className="w-full px-4 py-3 rounded-xl bg-input-background border border-border text-foreground placeholder:text-muted-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors resize-none" />
          <p className="text-muted-foreground text-[11px] mt-1 text-right">{draft.bio.length}/200</p></div>
      </div>
      <div className="mt-7 flex gap-3">
        <button onClick={() => navigate("profile")} className="flex-1 py-3 rounded-xl border border-border text-foreground/70 hover:text-foreground hover:bg-secondary transition-colors text-sm font-medium">Cancelar</button>
        <button onClick={() => { setUser({ ...user, ...draft }); navigate("profile"); }} className="flex-1 py-3 rounded-xl bg-primary text-primary-foreground font-semibold text-sm hover:opacity-90 active:scale-[0.98] transition-all">Guardar cambios</button>
      </div>
    </div>
  );
}

// ─── Login Page ───────────────────────────────────────────────────────────────

function LoginPage({ onVisitorLogin, onBusinessLogin, onAdminLogin }: {
  onVisitorLogin: () => void; onBusinessLogin: () => void; onAdminLogin: () => void;
}) {
  const [loginType, setLoginType] = useState<LoginType>("visitor");
  const [view, setView] = useState<AuthView>("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [name, setName] = useState("");
  const [bizCategory, setBizCategory] = useState("");
  const isB = loginType === "business";
  const handleLogin = () => (isB ? onBusinessLogin() : onVisitorLogin());

  return (
    <div className="min-h-screen w-full flex bg-background" style={{ fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
      {/* Left image */}
      <div className="hidden lg:flex lg:w-[56%] relative overflow-hidden flex-col">
        <img src="https://images.unsplash.com/photo-1771636001068-e90df5c47b93?w=1300&h=900&fit=crop&auto=format" alt="Playa tropical en Manzanillo" className="absolute inset-0 w-full h-full object-cover" />
        <div className="absolute inset-0 bg-gradient-to-t from-[#040f1a] via-[#040f1a]/50 to-transparent" />
        <div className="absolute inset-0 bg-gradient-to-r from-[#040f1a]/20 to-transparent" />
        <div className="relative z-10 p-9 flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-full bg-primary flex items-center justify-center shadow-lg shadow-primary/30"><Waves size={17} className="text-primary-foreground" /></div>
          <span className="text-white font-bold text-sm tracking-[0.18em] uppercase">TourisMAR</span>
        </div>
        <div className="relative z-10 mt-auto p-10 pb-12">
          <p className="text-primary text-xs tracking-[0.3em] uppercase font-semibold mb-4">Manzanillo · Colima</p>
          <h1 className="text-white leading-[1.1] mb-5" style={{ fontFamily: "'Playfair Display', serif", fontSize: "clamp(2.4rem, 3.5vw, 3.2rem)", fontWeight: 700 }}>
            Descubre el<br />Pacífico<br />Mexicano
          </h1>
          <p className="text-white/55 text-sm leading-relaxed max-w-xs">Playas, senderos de hiking, miradores y sabores locales — todo centralizado para explorar Manzanillo como nunca antes.</p>
          <div className="flex flex-wrap gap-2 mt-7">
            {["🏖 Playas", "🥾 Senderismo", "🍽 Restaurantes", "🗻 Miradores", "🎡 Recreación"].map((cat) => (
              <span key={cat} className="px-3 py-1.5 rounded-full text-xs text-white/75 border border-white/15 backdrop-blur-sm" style={{ background: "rgba(255,255,255,0.06)" }}>{cat}</span>
            ))}
          </div>
          <div className="flex gap-7 mt-8 pt-6 border-t border-white/10">
            {[{ value: "80+", label: "Lugares" }, { value: "4.8★", label: "Valoración media" }, { value: "360°", label: "Fotos inmersivas" }].map(({ value, label }) => (
              <div key={label}><p className="text-white font-bold text-lg leading-none">{value}</p><p className="text-white/45 text-[11px] mt-1">{label}</p></div>
            ))}
          </div>
        </div>
      </div>

      {/* Right form */}
      <div className="flex-1 flex flex-col items-center justify-center px-6 py-10 sm:px-12 overflow-y-auto">
        <div className="lg:hidden flex items-center gap-2.5 mb-10">
          <div className="w-9 h-9 rounded-full bg-primary flex items-center justify-center shadow-lg shadow-primary/30"><Waves size={17} className="text-primary-foreground" /></div>
          <span className="text-foreground font-bold text-sm tracking-[0.18em] uppercase">TourisMAR</span>
        </div>

        <div className="w-full max-w-[370px]">
          {/* Type toggle */}
          {(view === "login" || view === "register") && (
            <div className="flex p-1 rounded-xl bg-secondary border border-border mb-6">
              {(["visitor", "business"] as LoginType[]).map((type) => (
                <button key={type} type="button" onClick={() => setLoginType(type)}
                  className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-lg text-sm font-semibold transition-all ${loginType === type ? type === "business" ? "bg-accent text-accent-foreground shadow-sm" : "bg-primary text-primary-foreground shadow-sm" : "text-muted-foreground hover:text-foreground"}`}>
                  {type === "visitor" ? <><User size={14} />Visitante</> : <><Building2 size={14} />Empresa</>}
                </button>
              ))}
            </div>
          )}

          {/* LOGIN */}
          {view === "login" && (
            <div>
              <div className="mb-7">
                <h2 className="text-foreground text-[1.65rem] font-bold leading-tight mb-1.5" style={{ fontFamily: "'Playfair Display', serif" }}>
                  {isB ? "Accede a tu panel" : "Bienvenido de vuelta"}
                </h2>
                <p className="text-muted-foreground text-sm">{isB ? "Gestiona tu negocio o lugar turístico" : "Inicia sesión para seguir explorando Manzanillo"}</p>
              </div>
              <div className="space-y-4 mb-2">
                <div><FieldLabel>Correo electrónico</FieldLabel>
                  <div className="relative"><Mail size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
                    <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder={isB ? "contacto@minegocio.mx" : "tu@correo.com"}
                      className="w-full pl-10 pr-4 py-3 rounded-xl bg-input-background border border-border text-foreground placeholder:text-muted-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" />
                  </div>
                </div>
                <div><FieldLabel>Contraseña</FieldLabel><PasswordInput value={password} onChange={setPassword} /></div>
              </div>
              <div className="flex justify-end mb-5 mt-1">
                <button type="button" onClick={() => setView("forgot")} className="text-xs text-primary hover:opacity-75 transition-opacity">¿Olvidaste tu contraseña?</button>
              </div>
              <div className="flex items-center gap-3 mb-4"><div className="flex-1 h-px bg-border" /><span className="text-muted-foreground text-xs tracking-wide">o continúa con Google</span><div className="flex-1 h-px bg-border" /></div>
              <GoogleButton label="Continuar con Google" onClick={handleLogin} />
              <div className="my-4" />
              <PrimaryButton onClick={handleLogin} accent={isB}>{isB ? "Acceder al panel" : "Iniciar sesión"}</PrimaryButton>
              <p className="text-center text-sm text-muted-foreground mt-5">
                ¿No tienes cuenta?{" "}
                <button type="button" onClick={() => setView("register")} className="text-primary hover:opacity-75 font-semibold transition-opacity">
                  {isB ? "Registra tu negocio" : "Regístrate gratis"}
                </button>
              </p>
              {!isB && (
                <div className="mt-8 pt-6 border-t border-border space-y-3">
                  <button type="button" onClick={() => setLoginType("business")}
                    className="w-full flex items-center justify-between px-4 py-3.5 rounded-xl border border-border hover:border-accent/40 hover:bg-accent/5 transition-all group">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-lg bg-accent/10 flex items-center justify-center shrink-0"><Building2 size={14} className="text-accent" /></div>
                      <div className="text-left"><p className="text-foreground text-xs font-semibold">¿Tienes un negocio o lugar turístico?</p><p className="text-muted-foreground text-[11px] mt-0.5">Accede con tu cuenta de empresa</p></div>
                    </div>
                    <ChevronRight size={14} className="text-muted-foreground group-hover:text-accent transition-colors shrink-0 ml-2" />
                  </button>
                  {/* Admin access button */}
                  <button type="button" onClick={onAdminLogin}
                    className="w-full flex items-center justify-center gap-2 py-2.5 rounded-xl border border-violet-400/25 bg-violet-400/5 text-violet-400 hover:bg-violet-400/10 transition-colors text-xs font-semibold">
                    <Shield size={13} />Continuar como administrador
                  </button>
                </div>
              )}
            </div>
          )}

          {/* REGISTER */}
          {view === "register" && (
            <div>
              <button type="button" onClick={() => setView("login")} className="flex items-center gap-1.5 text-muted-foreground hover:text-foreground text-sm mb-6 transition-colors"><ArrowLeft size={14} />Volver</button>
              <div className="mb-7">
                <h2 className="text-foreground text-[1.65rem] font-bold leading-tight mb-1.5" style={{ fontFamily: "'Playfair Display', serif" }}>{isB ? "Registra tu negocio" : "Crea tu cuenta"}</h2>
                <p className="text-muted-foreground text-sm">{isB ? "Comienza a gestionar tu lugar en TourisMAR" : "Únete a la comunidad de exploradores de Manzanillo"}</p>
              </div>
              <div className="space-y-4 mb-5">
                <div><FieldLabel>{isB ? "Nombre del negocio" : "Nombre completo"}</FieldLabel>
                  <input type="text" value={name} onChange={(e) => setName(e.target.value)} placeholder={isB ? "Playa Audiencia Resort" : "Tu nombre"}
                    className="w-full px-4 py-3 rounded-xl bg-input-background border border-border text-foreground placeholder:text-muted-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" /></div>
                {isB && <div><FieldLabel>Categoría</FieldLabel>
                  <input type="text" value={bizCategory} onChange={(e) => setBizCategory(e.target.value)} placeholder="Ej. Playa · Restaurante · Mirador"
                    className="w-full px-4 py-3 rounded-xl bg-input-background border border-border text-foreground placeholder:text-muted-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" /></div>}
                <div><FieldLabel>Correo electrónico</FieldLabel>
                  <div className="relative"><Mail size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
                    <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder={isB ? "contacto@minegocio.mx" : "tu@correo.com"}
                      className="w-full pl-10 pr-4 py-3 rounded-xl bg-input-background border border-border text-foreground placeholder:text-muted-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" />
                  </div>
                </div>
                <div><FieldLabel>Contraseña</FieldLabel><PasswordInput value={password} onChange={setPassword} placeholder="Mínimo 8 caracteres" /></div>
                <div><FieldLabel>Confirmar contraseña</FieldLabel><PasswordInput value={confirmPassword} onChange={setConfirmPassword} placeholder="Repite tu contraseña" /></div>
              </div>
              {isB && <div className="mb-5 p-3.5 rounded-xl bg-secondary border border-border flex gap-3 items-start"><AlertCircle size={13} className="text-accent shrink-0 mt-0.5" /><p className="text-muted-foreground text-xs leading-relaxed">Tu registro será revisado por un administrador de TourisMAR antes de aparecer en el mapa.</p></div>}
              <PrimaryButton onClick={handleLogin} accent={isB}>{isB ? "Solicitar registro" : "Crear cuenta"}</PrimaryButton>
              <p className="text-center text-sm text-muted-foreground mt-5">¿Ya tienes cuenta?{" "}<button type="button" onClick={() => setView("login")} className="text-primary hover:opacity-75 font-semibold transition-opacity">Inicia sesión</button></p>
            </div>
          )}

          {/* FORGOT */}
          {view === "forgot" && (
            <div>
              <button type="button" onClick={() => setView("login")} className="flex items-center gap-1.5 text-muted-foreground hover:text-foreground text-sm mb-6 transition-colors"><ArrowLeft size={14} />Volver</button>
              <div className="mb-7">
                <div className="w-12 h-12 rounded-2xl bg-primary/10 border border-primary/20 flex items-center justify-center mb-5"><Mail size={20} className="text-primary" /></div>
                <h2 className="text-foreground text-[1.65rem] font-bold leading-tight mb-1.5" style={{ fontFamily: "'Playfair Display', serif" }}>Recupera tu acceso</h2>
                <p className="text-muted-foreground text-sm leading-relaxed">Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.</p>
              </div>
              <div className="mb-5"><FieldLabel>Correo electrónico</FieldLabel>
                <div className="relative"><Mail size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
                  <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="tu@correo.com"
                    className="w-full pl-10 pr-4 py-3 rounded-xl bg-input-background border border-border text-foreground placeholder:text-muted-foreground text-sm focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-colors" />
                </div>
              </div>
              <PrimaryButton onClick={() => setView("forgot-sent")}>Enviar enlace de recuperación</PrimaryButton>
            </div>
          )}

          {/* FORGOT SENT */}
          {view === "forgot-sent" && (
            <div className="text-center">
              <div className="w-16 h-16 rounded-full bg-primary/10 border border-primary/25 flex items-center justify-center mx-auto mb-6"><Mail size={26} className="text-primary" /></div>
              <h2 className="text-foreground text-2xl font-bold mb-2" style={{ fontFamily: "'Playfair Display', serif" }}>Revisa tu correo</h2>
              <p className="text-muted-foreground text-sm leading-relaxed mb-8">Si existe una cuenta con <span className="text-foreground font-medium">{email || "ese correo"}</span>, recibirás un enlace en los próximos minutos.</p>
              <button type="button" onClick={() => setView("login")} className="text-sm text-primary hover:opacity-75 font-semibold transition-opacity">Volver al inicio de sesión</button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── App Router ───────────────────────────────────────────────────────────────

export default function App() {
  const [page, setPage] = useState<Page>("login");
  const [user, setUser] = useState<UserProfile>(DEFAULT_USER);
  const [businesses, setBusinesses] = useState<BusinessProfile[]>([DEFAULT_BUSINESS, SECOND_BUSINESS]);
  const [activeBizIdx, setActiveBizIdx] = useState(0);

  if (page === "login") {
    return (
      <LoginPage
        onVisitorLogin={() => setPage("dashboard")}
        onBusinessLogin={() => setPage("b-dashboard")}
        onAdminLogin={() => setPage("a-dashboard")}
      />
    );
  }

  if (page.startsWith("a-")) {
    return (
      <AdminAuthShell navigate={setPage}>
        {page === "a-dashboard" && <AdminDashboardPage navigate={setPage} />}
        {page === "a-users" && <AdminUsersPage navigate={setPage} />}
        {page === "a-businesses" && <AdminBusinessesPage navigate={setPage} />}
        {page === "a-requests" && <AdminRequestsPage navigate={setPage} />}
        {page === "a-admins" && <AdminAdminsPage navigate={setPage} />}
      </AdminAuthShell>
    );
  }

  if (page.startsWith("b-")) {
    const activeBusiness = businesses[activeBizIdx];
    return (
      <BusinessAuthShell
        businesses={businesses}
        activeBizIdx={activeBizIdx}
        setActiveBizIdx={setActiveBizIdx}
        navigate={setPage}
      >
        {page === "b-dashboard" && <BusinessDashboardPage business={activeBusiness} navigate={setPage} />}
        {page === "b-profile" && <BusinessProfilePage business={activeBusiness} navigate={setPage} />}
        {page === "b-edit" && <BusinessEditPage business={activeBusiness}
          setBusiness={(b) => { const u = [...businesses]; u[activeBizIdx] = b; setBusinesses(u); }}
          navigate={setPage} />}
        {page === "b-reviews" && <BusinessReviewsPage business={activeBusiness} navigate={setPage} />}
      </BusinessAuthShell>
    );
  }

  return (
    <AuthShell user={user} navigate={setPage}>
      {page === "dashboard" && <DashboardPage user={user} navigate={setPage} />}
      {page === "profile" && <ProfilePage user={user} navigate={setPage} />}
      {page === "edit-profile" && <EditProfilePage user={user} setUser={setUser} navigate={setPage} />}
    </AuthShell>
  );
}
