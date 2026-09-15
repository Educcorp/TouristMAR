-- Notificaciones para admins (solicitudes/sugerencias de negocio, usuarios
-- nuevos) y para dueños de negocio (aprobado/rechazado). Una fila por
-- destinatario — al notificar a "los admins" se crea una fila por cada uno.
CREATE TYPE "notificacion_tipo_enum" AS ENUM ('negocio_pendiente', 'negocio_sugerido', 'negocio_aprobado', 'negocio_rechazado', 'usuario_nuevo');

CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "tipo" "notificacion_tipo_enum" NOT NULL,
    "titulo" TEXT NOT NULL,
    "cuerpo" TEXT NOT NULL,
    "negocio_id" UUID,
    "leida" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "notifications_user_id_leida_idx" ON "notifications"("user_id", "leida");

ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
