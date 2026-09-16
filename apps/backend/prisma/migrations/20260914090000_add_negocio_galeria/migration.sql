-- Galería de fotos de un negocio: arreglo de URLs a Supabase Storage que la
-- propia empresa gestiona (agregar/quitar) desde su panel.
ALTER TABLE "negocio_profiles" ADD COLUMN "galeria" TEXT[] NOT NULL DEFAULT '{}';
