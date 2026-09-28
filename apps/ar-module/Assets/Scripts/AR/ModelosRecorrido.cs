using System;

namespace TouristMAR.AR
{
    /// <summary>
    /// Una de las 3 fotos del recorrido: una foto 360° equirectangular (2:1) ya
    /// optimizada por el backend — JPG baseline de máx. 4096×2048, se carga con
    /// UnityWebRequestTexture y se pinta en una esfera invertida o en un skybox
    /// con el shader "Skybox/Panoramic".
    /// </summary>
    [Serializable]
    public class DatosEscena360
    {
        /// <summary>"Foto 1", "Foto 2" o "Foto 3" (su posición dentro de ESTE recorrido).</summary>
        public string titulo;
        public string urlImagen;
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
        /// <summary>
        /// Siempre 3, en orden: escenas[0] = "Foto 1", [1] = "Foto 2", [2] = "Foto 3".
        /// El backend solo publica recorridos con las 3 fotos, así que se puede
        /// indexar directo. Cada recorrido trae SUS fotos (URLs únicas): la
        /// "Foto 1" de la playa y la del restaurante son archivos distintos.
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
