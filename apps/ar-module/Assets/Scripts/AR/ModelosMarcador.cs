using System;

namespace TouristMAR.AR
{
    /// <summary>
    /// Un marcador tal como lo devuelve GET /api/marcadores. Contrato acordado
    /// con el backend (apps/backend/src/modules/ar/ar.controller.ts →
    /// toUnityMarcador): JsonUtility mapea por nombre de campo y deja en default,
    /// sin avisar, lo que no encuentra, así que estos nombres tienen que
    /// coincidir EXACTO con el JSON.
    /// </summary>
    [Serializable]
    public class DatosMarcador
    {
        /// <summary>Identificador único (ej. "gaviota_01"). Es el nombre de la imagen en la biblioteca de rastreo.</summary>
        public string nombre;
        public string urlImagen;
        /// <summary>Título y descripción en dos líneas, listo para ponerlo en el TextMeshPro.</summary>
        public string textoParaMostrar;
    }

    /// <summary>
    /// Raíz de la respuesta: { "marcadores": [ ... ] }. JsonUtility no
    /// deserializa un arreglo suelto, por eso viene envuelto en un objeto.
    /// </summary>
    [Serializable]
    public class ListaDesdeAdmin
    {
        public DatosMarcador[] marcadores;
    }

    /// <summary>Configuración que manda la app anfitriona (Flutter) al abrir el módulo.</summary>
    [Serializable]
    public class ConfigAR
    {
        /// <summary>Base de la API, con /api incluido. Ej: https://tu-app.com/api</summary>
        public string apiBaseUrl;
        /// <summary>JWT del turista si inició sesión; vacío = anónimo.</summary>
        public string token;
        /// <summary>
        /// Id del lugar desde el que se abrió (el mismo que usa Flutter). Si
        /// viene, solo se bajan los marcadores de ese lugar
        /// (GET /api/marcadores?negocioId=...); vacío = todos.
        /// </summary>
        public string lugarId;
    }

    /// <summary>Mensaje que Unity le manda a la app anfitriona (ver PuenteApp).</summary>
    [Serializable]
    public class EventoAR
    {
        /// <summary>"listo" | "marcadoresCargados" | "marcadorDetectado" | "error"</summary>
        public string evento;
        public string nombre;
        public string texto;
        public int total;
        public string mensaje;
    }
}
