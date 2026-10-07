import dotenv from 'dotenv'
import { z } from 'zod'

dotenv.config()

const envSchema = z.object({
  PORT: z.string().trim().optional(),
  HOST: z.string().trim().optional(),
  NODE_ENV: z.string().trim().default('development'),
  CORS_ORIGIN: z.string().trim().default('http://localhost:5173'),
  DATABASE_URL: z.string().trim().min(1, 'DATABASE_URL es requerido'),
  DIRECT_URL: z.string().trim().optional(),
  JWT_SECRET: z.string().trim().min(1, 'JWT_SECRET es requerido'),
  JWT_EXPIRES_IN: z.string().trim().default('7d'),
  GOOGLE_CLIENT_ID: z.string().trim().optional(),
  GOOGLE_CLIENT_SECRET: z.string().trim().optional(),
  GOOGLE_CALLBACK_URL: z.string().trim().optional(),
  SUPABASE_URL: z.string().trim().min(1, 'SUPABASE_URL es requerido'),
  SUPABASE_SERVICE_ROLE_KEY: z.string().trim().min(1, 'SUPABASE_SERVICE_ROLE_KEY es requerido'),
})

const parsed = envSchema.safeParse(process.env)

if (!parsed.success) {
  console.error('Variables de entorno inválidas:', parsed.error.flatten().fieldErrors)
  process.exit(1)
}

const esProduccion = parsed.data.NODE_ENV === 'production'

export const env = {
  ...parsed.data,
  // Todo se abre en el 5173. En producción el backend es el único servidor
  // (sirve la web y la API) y escucha ahí para toda la red. En desarrollo el
  // 5173 lo ocupa el servidor de Flutter, que reenvía /api/ a este backend
  // (apps/web/web_dev_config.yaml): por eso aquí escucha solo dentro de la PC,
  // en un puerto interno que nadie abre directo.
  PORT: parsed.data.PORT ?? (esProduccion ? '5173' : '5174'),
  HOST: parsed.data.HOST ?? (esProduccion ? '0.0.0.0' : '127.0.0.1'),
}
export const isGoogleAuthEnabled = Boolean(env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET)
