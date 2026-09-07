-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "sexo_enum" AS ENUM ('femenino', 'masculino', 'otro', 'prefiero_no_decir');

-- CreateEnum
CREATE TYPE "rol_enum" AS ENUM ('usuario', 'admin', 'super_admin');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT,
    "nombres" TEXT NOT NULL,
    "apellidos" TEXT,
    "username" TEXT,
    "fecha_nacimiento" DATE,
    "sexo" "sexo_enum",
    "rol" "rol_enum" NOT NULL DEFAULT 'usuario',
    "avatar_url" TEXT,
    "google_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "users_username_key" ON "users"("username");

-- CreateIndex
CREATE UNIQUE INDEX "users_google_id_key" ON "users"("google_id");

