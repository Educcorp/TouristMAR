-- Marcadores de realidad aumentada (imágenes que reconoce la cámara + la
-- información que se muestra encima) y el registro de escaneos para las
-- estadísticas. Los da de alta un admin desde el panel web; Unity consume la
-- lista pública en GET /api/ar/marcadores.
CREATE TYPE "ar_contenido_enum" AS ENUM ('texto', 'imagen', 'modelo_3d', 'video');

CREATE TABLE "ar_marcadores" (
    "id" UUID NOT NULL,
    "negocio_id" UUID,
    "nombre" TEXT NOT NULL,
    "imagen_url" TEXT NOT NULL,
    "imagen_path" TEXT NOT NULL,
    "ancho_metros" DOUBLE PRECISION,
    "titulo" TEXT NOT NULL,
    "texto" TEXT NOT NULL,
    "tipo_contenido" "ar_contenido_enum" NOT NULL DEFAULT 'texto',
    "contenido_url" TEXT,
    "activo" BOOLEAN NOT NULL DEFAULT true,
    "creado_por" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ar_marcadores_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ar_marcadores_activo_idx" ON "ar_marcadores"("activo");
CREATE INDEX "ar_marcadores_negocio_id_idx" ON "ar_marcadores"("negocio_id");

ALTER TABLE "ar_marcadores" ADD CONSTRAINT "ar_marcadores_negocio_id_fkey"
    FOREIGN KEY ("negocio_id") REFERENCES "negocio_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ar_marcadores" ADD CONSTRAINT "ar_marcadores_creado_por_fkey"
    FOREIGN KEY ("creado_por") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "ar_escaneos" (
    "id" UUID NOT NULL,
    "marcador_id" UUID NOT NULL,
    "user_id" UUID,
    "plataforma" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ar_escaneos_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ar_escaneos_marcador_id_created_at_idx" ON "ar_escaneos"("marcador_id", "created_at");

ALTER TABLE "ar_escaneos" ADD CONSTRAINT "ar_escaneos_marcador_id_fkey"
    FOREIGN KEY ("marcador_id") REFERENCES "ar_marcadores"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ar_escaneos" ADD CONSTRAINT "ar_escaneos_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
