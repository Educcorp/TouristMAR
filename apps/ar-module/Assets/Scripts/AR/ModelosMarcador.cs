using System;

namespace TouristMAR.AR
{
    /// <summary>
    /// Un marcador tal como lo devuelve GET /api/ar/marcadores.
    /// Los nombres de los campos tienen que coincidir EXACTO con el JSON del
    /// backend (apps/backend/src/modules/ar/ar.controller.ts → toUnityMarcador),
    /// porque JsonUtility mapea por nombre y en silencio deja en default lo que
    /// no encuentra.
    /// </summary>
    [Serializable]
    public class DatosMarcador
    {
        /// <summary>UUID; también es el nombre con el que la imagen se registra en la biblioteca de rastreo.</summary>
        public string id;
        public string nombre;
        public string imagenUrl;
        /// <summary>Ancho físico de la imagen impresa en metros. 0 = desconocido.</summary>
        public float anchoMetros;
        public string titulo;
        public string texto;
        /// <summary>"texto" | "imagen" | "modelo_3d" | "video". Hoy solo se pinta "texto".</summary>
        public string tipoContenido;
        public string contenidoUrl;
        public string negocioId;
        public string negocioNombre;
        public string actualizadoEn;
    }

    /// <summary>
    /// Raíz de la respuesta. JsonUtility no deserializa un arreglo suelto, por
    /// eso el backend envuelve la lista en un objeto.
    /// </summary>
    [Serializable]
    public class ListaDesdeAdmin
    {
        public string version;
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
    }

    /// <summary>Mensaje que Unity le manda a la app anfitriona (ver PuenteApp).</summary>
    [Serializable]
    public class EventoAR
    {
        /// <summary>"listo" | "marcadoresCargados" | "marcadorDetectado" | "error"</summary>
        public string evento;
        public string marcadorId;
        public string titulo;
        public string negocioId;
        public int total;
        public string mensaje;
    }
}
