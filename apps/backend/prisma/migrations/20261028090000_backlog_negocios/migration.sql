-- Notificación al visitante cuando un negocio responde su reseña.
ALTER TYPE "notificacion_tipo_enum" ADD VALUE 'resena_respondida';

-- Costo por persona y menú (opcionales) en la ficha del negocio.
ALTER TABLE "negocio_profiles" ADD COLUMN "costo_por_persona" TEXT;
ALTER TABLE "negocio_profiles" ADD COLUMN "menu" TEXT;

-- Visitas a la ficha de cada lugar.
CREATE TABLE "visitas_lugar" (
    "id" UUID NOT NULL,
    "negocio_id" UUID NOT NULL,
    "user_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "visitas_lugar_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "visitas_lugar_negocio_id_created_at_idx" ON "visitas_lugar"("negocio_id", "created_at");

ALTER TABLE "visitas_lugar" ADD CONSTRAINT "visitas_lugar_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "negocio_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "visitas_lugar" ADD CONSTRAINT "visitas_lugar_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Categorías de negocio administrables.
CREATE TABLE "categorias_negocio" (
    "id" UUID NOT NULL,
    "nombre" TEXT NOT NULL,
    "orden" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "categorias_negocio_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "categorias_negocio_nombre_key" ON "categorias_negocio"("nombre");

-- Las que ya existían fijas en el formulario de registro, más las del mapa.
INSERT INTO "categorias_negocio" ("id", "nombre", "orden") VALUES
    (gen_random_uuid(), 'Playa', 0),
    (gen_random_uuid(), 'Restaurante', 1),
    (gen_random_uuid(), 'Club de playa', 2),
    (gen_random_uuid(), 'Club nocturno', 3),
    (gen_random_uuid(), 'Hotel', 4),
    (gen_random_uuid(), 'Mirador', 5),
    (gen_random_uuid(), 'Cultura', 6),
    (gen_random_uuid(), 'Recreación', 7);
