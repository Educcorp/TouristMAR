-- Una cuenta de negocio puede tener más de un negocio: se quita la
-- restricción de unicidad sobre user_id (antes forzaba 1:1) y se deja un
-- índice normal para no perder velocidad en los lookups por dueño.
DROP INDEX "negocio_profiles_user_id_key";
CREATE INDEX "negocio_profiles_user_id_idx" ON "negocio_profiles"("user_id");
