-- "Mis favoritos" del visitante: un lugar (negocio) guardado por usuario.
CREATE TABLE "favoritos" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "negocio_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "favoritos_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "favoritos_user_id_negocio_id_key" ON "favoritos"("user_id", "negocio_id");
CREATE INDEX "favoritos_user_id_created_at_idx" ON "favoritos"("user_id", "created_at");

ALTER TABLE "favoritos" ADD CONSTRAINT "favoritos_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "favoritos" ADD CONSTRAINT "favoritos_negocio_id_fkey"
    FOREIGN KEY ("negocio_id") REFERENCES "negocio_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;
