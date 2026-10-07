-- Reseñas de visitantes sobre los lugares (negocios): estrellas 1-5, comentario
-- opcional y respuesta del negocio. Una reseña por usuario y lugar.
CREATE TABLE "resenas" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "negocio_id" UUID NOT NULL,
    "estrellas" INTEGER NOT NULL,
    "comentario" TEXT,
    "respuesta" TEXT,
    "respuesta_en" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "resenas_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "resenas_estrellas_check" CHECK ("estrellas" BETWEEN 1 AND 5)
);

CREATE UNIQUE INDEX "resenas_user_id_negocio_id_key" ON "resenas"("user_id", "negocio_id");
CREATE INDEX "resenas_negocio_id_created_at_idx" ON "resenas"("negocio_id", "created_at");

ALTER TABLE "resenas" ADD CONSTRAINT "resenas_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "resenas" ADD CONSTRAINT "resenas_negocio_id_fkey"
    FOREIGN KEY ("negocio_id") REFERENCES "negocio_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;
