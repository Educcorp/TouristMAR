-- `nombre` pasa a ser el identificador del marcador en el contrato con Unity
-- (GET /api/marcadores): es el nombre con el que se registra cada imagen en
-- la biblioteca de rastreo, así que no puede repetirse.
CREATE UNIQUE INDEX "ar_marcadores_nombre_key" ON "ar_marcadores"("nombre");
