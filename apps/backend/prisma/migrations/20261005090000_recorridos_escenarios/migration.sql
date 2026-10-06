-- Recorridos 360° por escenarios: un recorrido deja de ser "exactamente 3
-- fotos" y pasa a ser de 1 a 32 escenarios (fotos 360° ya unidas) conectados
-- con flechas. Las fotos que ya existen se conservan como Escenario 1, 2 y 3.

ALTER TABLE "recorrido_360_escenas"
    ADD COLUMN "titulo" TEXT NOT NULL DEFAULT '',
    ADD COLUMN "descripcion" TEXT NOT NULL DEFAULT '',
    ADD COLUMN "yaw_inicial" DOUBLE PRECISION NOT NULL DEFAULT 0;

-- Casillas válidas: 0..31 (Escenario 1..32).
ALTER TABLE "recorrido_360_escenas"
    ADD CONSTRAINT "recorrido_360_escenas_orden_check" CHECK ("orden" >= 0 AND "orden" < 32);

CREATE TABLE "recorrido_360_enlaces" (
    "id" UUID NOT NULL,
    "origen_id" UUID NOT NULL,
    "destino_id" UUID NOT NULL,
    "yaw" DOUBLE PRECISION NOT NULL,
    "pitch" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "etiqueta" TEXT NOT NULL DEFAULT '',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recorrido_360_enlaces_pkey" PRIMARY KEY ("id"),
    -- Una flecha nunca apunta al mismo escenario donde está.
    CONSTRAINT "recorrido_360_enlaces_distintos_check" CHECK ("origen_id" <> "destino_id")
);

-- Una sola flecha de A hacia B (la de B hacia A es otra fila).
CREATE UNIQUE INDEX "recorrido_360_enlaces_origen_id_destino_id_key" ON "recorrido_360_enlaces"("origen_id", "destino_id");
CREATE INDEX "recorrido_360_enlaces_destino_id_idx" ON "recorrido_360_enlaces"("destino_id");

-- Al borrar un escenario se van sus flechas y las que llegaban a él.
ALTER TABLE "recorrido_360_enlaces" ADD CONSTRAINT "recorrido_360_enlaces_origen_id_fkey"
    FOREIGN KEY ("origen_id") REFERENCES "recorrido_360_escenas"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "recorrido_360_enlaces" ADD CONSTRAINT "recorrido_360_enlaces_destino_id_fkey"
    FOREIGN KEY ("destino_id") REFERENCES "recorrido_360_escenas"("id") ON DELETE CASCADE ON UPDATE CASCADE;
