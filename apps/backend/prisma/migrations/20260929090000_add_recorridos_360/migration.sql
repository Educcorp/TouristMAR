-- Recorridos 360°: cada recorrido tiene 3 fotos 360° equirectangulares
-- ("Foto 1", "Foto 2", "Foto 3"; ya optimizadas por el backend). Los da de
-- alta un admin desde el panel web; Unity consume la lista pública en
-- GET /api/recorridos.
CREATE TABLE "recorridos_360" (
    "id" UUID NOT NULL,
    "negocio_id" UUID,
    "nombre" TEXT NOT NULL,
    "titulo" TEXT NOT NULL,
    "texto" TEXT NOT NULL,
    "activo" BOOLEAN NOT NULL DEFAULT true,
    "creado_por" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "recorridos_360_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "recorrido_360_escenas" (
    "id" UUID NOT NULL,
    "recorrido_id" UUID NOT NULL,
    "orden" INTEGER NOT NULL,
    "imagen_url" TEXT NOT NULL,
    "imagen_path" TEXT NOT NULL,
    "miniatura_url" TEXT NOT NULL,
    "miniatura_path" TEXT NOT NULL,
    "ancho" INTEGER NOT NULL,
    "alto" INTEGER NOT NULL,
    "peso_bytes" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "recorrido_360_escenas_pkey" PRIMARY KEY ("id")
);

-- `nombre` es el identificador del recorrido en el contrato con Unity.
CREATE UNIQUE INDEX "recorridos_360_nombre_key" ON "recorridos_360"("nombre");
CREATE INDEX "recorridos_360_activo_idx" ON "recorridos_360"("activo");
CREATE INDEX "recorridos_360_negocio_id_idx" ON "recorridos_360"("negocio_id");
-- Una foto por casilla: `orden` 0, 1, 2 = Foto 1, Foto 2, Foto 3.
CREATE UNIQUE INDEX "recorrido_360_escenas_recorrido_id_orden_key" ON "recorrido_360_escenas"("recorrido_id", "orden");

ALTER TABLE "recorridos_360" ADD CONSTRAINT "recorridos_360_negocio_id_fkey"
    FOREIGN KEY ("negocio_id") REFERENCES "negocio_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recorridos_360" ADD CONSTRAINT "recorridos_360_creado_por_fkey"
    FOREIGN KEY ("creado_por") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "recorrido_360_escenas" ADD CONSTRAINT "recorrido_360_escenas_recorrido_id_fkey"
    FOREIGN KEY ("recorrido_id") REFERENCES "recorridos_360"("id") ON DELETE CASCADE ON UPDATE CASCADE;
