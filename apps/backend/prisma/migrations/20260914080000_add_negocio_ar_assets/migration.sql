-- Recursos AR/360 por negocio. Cada negocio puede subir su propio archivo
-- 360° y los modelos de AR (marcador físico y geolocalización) desde su
-- panel; por ahora son URLs sueltas a Supabase Storage, sin metadata extra.
ALTER TABLE "negocio_profiles" ADD COLUMN "archivo_360" TEXT;
ALTER TABLE "negocio_profiles" ADD COLUMN "ar_marcador_url" TEXT;
ALTER TABLE "negocio_profiles" ADD COLUMN "ar_geo_url" TEXT;
