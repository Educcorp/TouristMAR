-- Renombrar el valor existente del enum en vez de borrarlo, para no romper filas ya guardadas
ALTER TYPE "rol_enum" RENAME VALUE 'usuario' TO 'turista';

-- Nuevo tipo de cuenta: negocio
ALTER TYPE "rol_enum" ADD VALUE 'negocio';

-- Nuevo default acorde al rename anterior
ALTER TABLE "users" ALTER COLUMN "rol" SET DEFAULT 'turista';

-- Bio para perfil de turista
ALTER TABLE "users" ADD COLUMN "bio" TEXT;

-- Estado de aprobación de negocios
CREATE TYPE "estado_negocio_enum" AS ENUM ('pendiente', 'aprobado', 'rechazado');

-- Perfil de negocio, 1 a 1 con users
CREATE TABLE "negocio_profiles" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "nombre" TEXT NOT NULL,
    "categoria" TEXT,
    "descripcion" TEXT,
    "direccion" TEXT,
    "telefono" TEXT,
    "sitio_web" TEXT,
    "horario" TEXT,
    "portada" TEXT,
    "estado" "estado_negocio_enum" NOT NULL DEFAULT 'pendiente',
    "revisado_por" UUID,
    "revisado_en" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "negocio_profiles_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "negocio_profiles_user_id_key" ON "negocio_profiles"("user_id");

ALTER TABLE "negocio_profiles" ADD CONSTRAINT "negocio_profiles_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
