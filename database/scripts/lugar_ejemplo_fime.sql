-- Lugar de ejemplo para probar el mapa → "Ver en 360°" → recorrido.
-- Coordenadas reales del punto (19.12492145230218, -104.40020700589847).
--
-- Igual que POST /api/admin/lugares: aprobado y a nombre del super admin
-- (la cuenta que no se puede borrar). Si ya existe un lugar con ese nombre,
-- no hace nada (se puede correr varias veces).
--
-- Correr desde apps/backend:
--   npx prisma db execute --file ../../database/scripts/lugar_ejemplo_fime.sql --schema prisma/schema.prisma
INSERT INTO "negocio_profiles" (
    "id", "user_id", "nombre", "categoria", "descripcion", "direccion",
    "latitud", "longitud", "estado", "revisado_por", "revisado_en", "created_at", "updated_at"
)
SELECT
    gen_random_uuid(),
    sa."id",
    'Facultad de Ingeniería Electromecánica (FIME)',
    'Cultura y educación',
    'Facultad de la Universidad de Colima en Manzanillo. Recorre su explanada y edificios en 360°.',
    'Universidad de Colima, Campus El Naranjo, Manzanillo, Col.',
    19.12492145230218,
    -104.40020700589847,
    'aprobado',
    sa."id",
    now(),
    now(),
    now()
FROM (
    SELECT "id" FROM "users" WHERE "rol" = 'super_admin' ORDER BY "created_at" LIMIT 1
) AS sa
WHERE NOT EXISTS (
    SELECT 1 FROM "negocio_profiles" WHERE "nombre" = 'Facultad de Ingeniería Electromecánica (FIME)'
);
