process.env.DATABASE_URL ??= 'postgresql://test:test@localhost:5432/test'
process.env.JWT_SECRET ??= 'test-secret'
process.env.JWT_EXPIRES_IN ??= '1h'
process.env.CORS_ORIGIN ??= 'http://localhost:5173'
process.env.SUPABASE_URL ??= 'https://test.supabase.co'
process.env.SUPABASE_SERVICE_ROLE_KEY ??= 'test-service-role-key'

// Aislar los tests del .env real: si el backend ya tiene credenciales de Google
// configuradas localmente, no deben filtrarse a los tests que asumen que Google
// OAuth está deshabilitado.
// dotenv no sobreescribe variables ya definidas, así que fijarlas vacías (no
// borrarlas) es lo que evita que las credenciales reales del .env se cuelen.
process.env.GOOGLE_CLIENT_ID = ''
process.env.GOOGLE_CLIENT_SECRET = ''
process.env.GOOGLE_CALLBACK_URL = ''
