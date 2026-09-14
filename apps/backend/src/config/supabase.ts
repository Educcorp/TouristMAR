import { createClient } from '@supabase/supabase-js'
import { env } from './env'

export const supabase = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
})

export const AVATARS_BUCKET = 'avatars'
export const NEGOCIO_ASSETS_BUCKET = 'negocio-assets'
