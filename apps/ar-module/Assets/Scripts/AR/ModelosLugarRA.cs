using System;

namespace TouristMAR.AR
{
    /// <summary>
    /// Punto de interés de la RA por geolocalización. Funciona por capas:
    /// dentro de <see cref="radioVisible"/> se muestra un marcador flotante con
    /// <see cref="titulo"/> y <see cref="resumen"/> en la dirección del punto;
    /// dentro de <see cref="radioCercano"/> el GPS ya no es lo bastante preciso
    /// y la experiencia pasa a los marcadores de imagen colocados en el lugar
    /// (escena de marcadores, GET /api/marcadores).
    /// </summary>
    [Serializable]
    public class DatosPuntoRA
    {
        public string id;
        public string titulo;
        /// <summary>Una o dos líneas para el marcador flotante.</summary>
        public string resumen;
        /// <summary>La guía completa al llegar.</summary>
        public string detalle;
        /// <summary>"" si no tiene.</summary>
        public string urlImagen;
        /// <summary>Guía de audio (MP3/OGG público). "" si no tiene.</summary>
        public string urlAudio;
        /// <summary>Grados decimales (WGS84).</summary>
        public double latitud;
        public double longitud;
        /// <summary>Metros: a esta distancia aparece el marcador flotante.</summary>
        public float radioVisible;
        /// <summary>Metros: a esta distancia se deja la geolocalización y entran los marcadores del lugar (siempre menor que radioVisible).</summary>
        public float radioCercano;
    }

    /// <summary>
    /// Un lugar para la RA por geolocalización, tal como lo devuelve
    /// GET /api/ra/lugares (backend: apps/backend/src/modules/lugares/ra-lugares.controller.ts
    /// → toUnityLugar). JsonUtility mapea por nombre de campo y deja en default,
    /// sin avisar, lo que no encuentra: estos nombres tienen que coincidir EXACTO.
    /// Nunca vienen null: lo que falta llega como "".
    /// </summary>
    [Serializable]
    public class DatosLugarRA
    {
        /// <summary>Id del lugar (el mismo que usa la app).</summary>
        public string id;
        public string nombre;
        public string categoria;
        /// <summary>Nombre y, en la siguiente línea, la descripción.</summary>
        public string textoParaMostrar;
        public string direccion;
        /// <summary>Foto de portada (PNG/JPG público). "" si no tiene.</summary>
        public string urlPortada;
        /// <summary>Pin del lugar en grados decimales (WGS84), el mismo del mapa de la app.</summary>
        public double latitud;
        public double longitud;
        /// <summary>
        /// Nunca viene vacío: si el admin no dio de alta puntos, trae uno solo
        /// con el pin del lugar y los radios por defecto (100 m / 10 m).
        /// </summary>
        public DatosPuntoRA[] puntos;
        /// <summary>
        /// Si el lugar tiene marcadores de imagen activos (GET /api/marcadores).
        /// La app ofrece "Abrir RA con marcadores" al entrar al radioCercano.
        /// </summary>
        public bool tieneMarcadores;
    }

    /// <summary>Raíz de GET /api/ra/lugares: { "lugares": [ ... ] }.</summary>
    [Serializable]
    public class ListaLugaresRA
    {
        public DatosLugarRA[] lugares;
    }

    /// <summary>Raíz de GET /api/ra/lugares/{id}: { "lugar": { ... } }.</summary>
    [Serializable]
    public class RespuestaLugarRA
    {
        public DatosLugarRA lugar;
    }
}
