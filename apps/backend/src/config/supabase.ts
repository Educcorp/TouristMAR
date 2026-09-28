import { createClient } from '@supabase/supabase-js'
import { env } from './env'

export const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
})

export const AVATARS_BUCKET = 'avatars'
export const NEGOCIO_ASSETS_BUCKET = 'negocio-assets'
/// Imágenes que reconoce la cámara AR (una carpeta por marcador). Tiene que
/// ser público: Unity descarga las imágenes directo de la URL, sin token.
export const AR_MARCADORES_BUCKET = 'ar-marcadores'
/// Escenas de los recorridos 360° (una carpeta por recorrido). Público por el
/// mismo motivo: Unity descarga las fotos directo de la URL.
export const RECORRIDOS_360_BUCKET = 'recorridos-360'
