-- Cuentas bloqueables desde el panel de administración (turistas y negocios).
-- Los admins/super_admin nunca se bloquean desde esta bandera.
ALTER TABLE "users" ADD COLUMN "activo" BOOLEAN NOT NULL DEFAULT true;

-- Alta del único super administrador del sistema. Contraseña ya hasheada con
-- bcrypt (10 rounds) para 'Numpy3020'. Idempotente: si ya existe ese correo
-- (por ejemplo al re-ejecutar migraciones en otro entorno), no hace nada.
INSERT INTO "users" ("id", "email", "password_hash", "nombres", "rol", "activo", "created_at", "updated_at")
VALUES (
    'ff76c9e8-a3e7-47c2-a906-7907584033d8',
    'educcorp3@gmail.com',
    '$2a$10$pFFv0Jb/76ksQBrM7lBx0uotcDw017iTrXKBm6z21DdGvxH2L82aK',
    'Super Admin',
    'super_admin',
    true,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
)
ON CONFLICT ("email") DO NOTHING;
