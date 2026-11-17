-- "¿Olvidaste tu contraseña?": códigos de recuperación enviados por correo.
-- Solo se guarda el hash del código; caduca, sirve una vez y tiene límite de intentos.
CREATE TABLE "recuperaciones_password" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "codigo_hash" TEXT NOT NULL,
    "expira_en" TIMESTAMP(3) NOT NULL,
    "usado_en" TIMESTAMP(3),
    "intentos" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recuperaciones_password_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "recuperaciones_password_user_id_created_at_idx" ON "recuperaciones_password"("user_id", "created_at");

ALTER TABLE "recuperaciones_password" ADD CONSTRAINT "recuperaciones_password_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
