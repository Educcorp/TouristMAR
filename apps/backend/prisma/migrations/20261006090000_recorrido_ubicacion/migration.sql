-- Pin propio de cada recorrido 360° en el mapa (lo captura el admin al
-- registrarlo). Nullable: los recorridos que ya existen se quedan sin
-- ubicación hasta que se les ponga.
ALTER TABLE "recorridos_360" ADD COLUMN "latitud" DOUBLE PRECISION;
ALTER TABLE "recorridos_360" ADD COLUMN "longitud" DOUBLE PRECISION;
