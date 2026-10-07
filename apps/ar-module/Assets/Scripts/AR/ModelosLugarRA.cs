using System;

namespace TouristMAR.AR
{
    /// <summary>
    /// Un lugar para la RA por ubicación, tal como lo devuelve
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
        /// <summary>Radio en metros alrededor del pin donde se activa la RA.</summary>
        public float radioMetros;
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
