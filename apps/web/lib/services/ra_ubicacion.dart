// RA por geolocalización: funciona con cualquier lugar que tenga pin en el
// mapa. Flutter y Unity identifican el lugar por su id y leen sus puntos de
// GET /api/ra/lugares/{id} (ver docs/manuals/ra_geolocalizacion.md).

/// Aviso para un lugar que todavía no tiene RA por geolocalización (sin pin).
String sinRaUbicacion(String lugarNombre) =>
    '$lugarNombre por el momento no cuenta con RA por geolocalización.';
