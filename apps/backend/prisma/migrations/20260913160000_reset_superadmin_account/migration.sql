-- La migración anterior (add_admin_panel) insertaba al super admin con
-- ON CONFLICT DO NOTHING: si ese correo ya existía como otra cuenta (por
-- ejemplo alguien ya se había registrado como turista con ese email), el
-- insert no hacía nada y la cuenta quedaba con el rol/contraseña viejos.
--
-- Esta migración fuerza el estado correcto sin importar si la fila ya
-- existía: upsert por correo, y si el usuario tenía un perfil de negocio
-- colgado se elimina (un super_admin no debe tener negocio_profile).
DELETE FROM "negocio_profiles"
WHERE "user_id" = (SELECT "id" FROM "users" WHERE "email" = 'educcorp3@gmail.com');

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
ON CONFLICT ("email") DO UPDATE SET
    "password_hash" = EXCLUDED."password_hash",
    "nombres" = EXCLUDED."nombres",
    "rol" = 'super_admin',
    
    "activo" = true,
    "google_id" = NULL,
    "updated_at" = CURRENT_TIMESTAMP;
