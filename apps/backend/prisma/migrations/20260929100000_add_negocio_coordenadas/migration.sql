-- Coordenadas del pin de un negocio en el mapa. Nullable: la mayoría de los
-- negocios todavía no tienen ubicación (el dueño la fija desde su panel, o
-- se completa a mano como abajo mientras esa pantalla no existe).
ALTER TABLE "negocio_profiles" ADD COLUMN "latitud" DOUBLE PRECISION;
ALTER TABLE "negocio_profiles" ADD COLUMN "longitud" DOUBLE PRECISION;

-- Semilla puntual a partir de PLAYAS.xlsx (coordenadas reales de playas de
-- Manzanillo/Armería/Tecomán, entregadas 2026-09-29): solo se completan los
-- negocios aprobados cuyo nombre coincide EXACTO con una playa del archivo.
-- "Playa Las Brisas" aparece dos veces en el Excel con coordenadas distintas
-- (19.0675,-104.3030 y 19.0833,-104.3218, ambas en Manzanillo) — se usó la
-- primera; si no es la correcta, ajustar aquí o desde el panel admin.
-- El resto de los negocios existentes (restaurantes, y nombres/categorías
-- que no calzan con ninguna playa del Excel: "Pata Salada", "Playa Bonita
-- Resort & Bar", cuentas de prueba) se dejan sin coordenadas a propósito.
UPDATE "negocio_profiles"
SET "latitud" = 19.0674847, "longitud" = -104.303045
WHERE "nombre" = 'Playa Las Brisas' AND "estado" = 'aprobado';
