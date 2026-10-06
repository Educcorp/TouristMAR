using System;

namespace TouristMAR.AR
{
    /// <summary>
    /// Flecha (hotspot) dentro de un escenario que lleva a otro escenario del
    /// mismo recorrido. Ángulos en grados sobre la foto equirectangular:
    /// yaw -180…180 (0 = centro de la foto, positivo hacia la derecha) y pitch
    /// -90…90 (0 = horizonte, negativo = hacia el piso).
    /// </summary>
    [Serializable]
    public class DatosEnlace360
    {
        /// <summary>Id del escenario destino (DatosEscena360.id).</summary>
        public string destino;
        public float yaw;
        public float pitch;
        /// <summary>Texto junto a la flecha; si el admin no puso uno, viene el título del destino.</summary>
        public string etiqueta;
    }

    /// <summary>
    /// Un escenario del recorrido: una foto 360° equirectangular (2:1) ya
    /// optimizada por el backend — JPG baseline de máx. 4096×2048, se carga con
    /// UnityWebRequestTexture y se pinta en una esfera invertida o en un skybox
    /// con el shader "Skybox/Panoramic".
    /// </summary>
    [Serializable]
    public class DatosEscena360
    {
        public string id;
        /// <summary>Nombre para el turista ("Lobby"); si no tiene, "Escenario N".</summary>
        public string titulo;
        public string descripcion;
        public string urlImagen;
        /// <summary>Miniatura 640×320, para un menú de escenarios sin bajar la foto completa.</summary>
        public string urlMiniatura;
        /// <summary>Hacia dónde mira la cámara al entrar, en grados (mismo eje que DatosEnlace360.yaw).</summary>
        public float yawInicial;
        /// <summary>Puede venir vacío (escenario sin salida más que "atrás").</summary>
        public DatosEnlace360[] enlaces;
    }

    /// <summary>
    /// Un recorrido tal como lo devuelve GET /api/recorridos. Contrato acordado
    /// con el backend (apps/backend/src/modules/recorridos/recorridos.controller.ts
    /// → toUnityRecorrido): JsonUtility mapea por nombre de campo y deja en
    /// default, sin avisar, lo que no encuentra, así que estos nombres tienen
    /// que coincidir EXACTO con el JSON.
    /// </summary>
    [Serializable]
    public class DatosRecorrido360
    {
        /// <summary>Identificador único (ej. "cerro_vigia_360").</summary>
        public string nombre;
        /// <summary>Título y descripción en dos líneas, igual que en los marcadores.</summary>
        public string textoParaMostrar;
        /// <summary>Id del negocio dueño del recorrido; "" si es general del destino.</summary>
        public string negocioId;
        /// <summary>Miniatura (640×320) de la primera escena, para menús. "" si no hay.</summary>
        public string urlPortada;
        /// <summary>Si el recorrido tiene pin en el mapa. Si es false, latitud y longitud vienen en 0.</summary>
        public bool tieneUbicacion;
        /// <summary>Coordenadas del recorrido (grados decimales, WGS84).</summary>
        public double latitud;
        public double longitud;
        /// <summary>Id del escenario por el que se entra (siempre el primero de <see cref="escenas"/>).</summary>
        public string escenaInicial;
        /// <summary>
        /// De 1 a 32 escenarios, en orden de casilla. No asumir un número fijo
        /// ni navegar por índice: moverse siguiendo los enlaces por id. Cada
        /// recorrido trae SUS fotos (URLs únicas).
        /// </summary>
        public DatosEscena360[] escenas;
    }

    /// <summary>Raíz de GET /api/recorridos: { "recorridos": [ ... ] }.</summary>
    [Serializable]
    public class ListaRecorridos
    {
        public DatosRecorrido360[] recorridos;
    }

    /// <summary>Raíz de GET /api/recorridos/{nombre}: { "recorrido": { ... } }.</summary>
    [Serializable]
    public class RespuestaRecorrido
    {
        public DatosRecorrido360 recorrido;
    }
}
