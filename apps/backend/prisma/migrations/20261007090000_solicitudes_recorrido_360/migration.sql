-- Solicitudes de recorrido 360° que mandan los negocios desde "Editar negocio"
-- (el admin las atiende en "Solicitudes"), más sus tipos de notificación.
-- CreateEnum
CREATE TYPE "solicitud_recorrido_estado_enum" AS ENUM ('pendiente', 'completada', 'rechazada');

-- AlterEnum


ALTER TYPE "notificacion_tipo_enum" ADD VALUE 'recorrido_solicitado';
ALTER TYPE "notificacion_tipo_enum" ADD VALUE 'recorrido_listo';
ALTER TYPE "notificacion_tipo_enum" ADD VALUE 'recorrido_rechazado';

-- CreateTable
CREATE TABLE "solicitudes_recorrido_360" (
    "id" UUID NOT NULL,
    "negocio_id" UUID NOT NULL,
    "mensaje" TEXT NOT NULL DEFAULT '',
    "estado" "solicitud_recorrido_estado_enum" NOT NULL DEFAULT 'pendiente',
    "nota" TEXT NOT NULL DEFAULT '',
    "atendida_por" UUID,
    "atendida_en" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "solicitudes_recorrido_360_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "solicitudes_recorrido_360_negocio_id_created_at_idx" ON "solicitudes_recorrido_360"("negocio_id", "created_at");

-- CreateIndex
CREATE INDEX "solicitudes_recorrido_360_estado_created_at_idx" ON "solicitudes_recorrido_360"("estado", "created_at");

-- AddForeignKey
ALTER TABLE "solicitudes_recorrido_360" ADD CONSTRAINT "solicitudes_recorrido_360_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "negocio_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "solicitudes_recorrido_360" ADD CONSTRAINT "solicitudes_recorrido_360_atendida_por_fkey" FOREIGN KEY ("atendida_por") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

