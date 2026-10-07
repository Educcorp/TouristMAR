-- Puntos de interés de la RA por geolocalización (radio visible y radio cercano).
-- CreateTable
CREATE TABLE "ra_geo_puntos" (
    "id" UUID NOT NULL,
    "negocio_id" UUID NOT NULL,
    "titulo" TEXT NOT NULL,
    "resumen" TEXT NOT NULL DEFAULT '',
    "detalle" TEXT NOT NULL DEFAULT '',
    "imagen_url" TEXT NOT NULL DEFAULT '',
    "audio_url" TEXT NOT NULL DEFAULT '',
    "latitud" DOUBLE PRECISION NOT NULL,
    "longitud" DOUBLE PRECISION NOT NULL,
    "radio_visible" DOUBLE PRECISION NOT NULL DEFAULT 100,
    "radio_cercano" DOUBLE PRECISION NOT NULL DEFAULT 10,
    "orden" INTEGER NOT NULL DEFAULT 0,
    "activo" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ra_geo_puntos_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ra_geo_puntos_negocio_id_orden_idx" ON "ra_geo_puntos"("negocio_id", "orden");

-- AddForeignKey
ALTER TABLE "ra_geo_puntos" ADD CONSTRAINT "ra_geo_puntos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "negocio_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

