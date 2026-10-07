using TouristMAR.AR;
using UnityEngine;
#if FLUTTER_UNITY_WIDGET
using FlutterUnityIntegration;
#endif

namespace TouristMAR
{
    /// <summary>
    /// Puente entre la app anfitriona (Flutter, vía flutter_unity_widget) y
    /// el módulo AR. El GameObject de la escena TIENE que llamarse "PuenteApp":
    /// Flutter le escribe por nombre con
    /// <c>controller.postMessage('PuenteApp', 'Configurar', json)</c>.
    ///
    /// El contrato de mensajes está duplicado del lado de Flutter en
    /// apps/mobile/lib/ar_bridge/ar_bridge.dart — si cambias algo aquí,
    /// cámbialo allá también.
    ///
    /// Para compilar con el envío real a Flutter, agrega el símbolo
    /// FLUTTER_UNITY_WIDGET en Project Settings → Player → Scripting Define
    /// Symbols (después de importar el paquete de flutter_unity_widget). Sin
    /// él, los eventos solo se imprimen en consola — útil en el Editor.
    /// </summary>
    public class PuenteApp : MonoBehaviour
    {
        [SerializeField] private MarcadorDinamico marcadores;

        [Header("Solo para probar en el Editor / build suelto")]
        // La API está en el 5173, igual que el sitio (/api). Con http:// (sin
        // "s") hay que permitirlo en Player → Other Settings → "Allow downloads
        // over HTTP", o Unity rechaza la conexión.
        [Tooltip("API en el 5173 (http://<IP-de-la-PC>:5173/api). En un celular 'localhost' es el propio celular: usa la IP de tu PC o la URL de producción.")]
        [SerializeField] private string apiBaseUrlPorDefecto = "http://localhost:5173/api";

        private bool configurado;

        private void Start()
        {
            Enviar(new EventoAR { evento = "listo" });

#if UNITY_EDITOR || !FLUTTER_UNITY_WIDGET
            // Sin app anfitriona nadie va a mandar "Configurar": se arranca solo.
            if (!configurado) Configurar(JsonUtility.ToJson(new ConfigAR { apiBaseUrl = apiBaseUrlPorDefecto }));
#endif
        }

        // --- Flutter → Unity (métodos invocados por nombre) -----------------

        /// <summary>json: {"apiBaseUrl":"https://.../api","token":"<jwt opcional>"}</summary>
        public void Configurar(string json)
        {
            var config = JsonUtility.FromJson<ConfigAR>(json);
            if (config == null || string.IsNullOrEmpty(config.apiBaseUrl))
            {
                EnviarError("Configuración inválida: falta apiBaseUrl");
                return;
            }
            configurado = true;
            marcadores.Iniciar(config, this);
        }

        /// <summary>Vuelve a descargar la lista de marcadores.</summary>
        public void Recargar(string _)
        {
            marcadores.Recargar();
        }

        // --- Unity → Flutter ------------------------------------------------

        public void Enviar(EventoAR evento)
        {
            var json = JsonUtility.ToJson(evento);
#if FLUTTER_UNITY_WIDGET
            UnityMessageManager.Instance.SendMessageToFlutter(json);
#else
            Debug.Log($"[PuenteApp] → app: {json}");
#endif
        }

        public void EnviarError(string mensaje)
        {
            Debug.LogWarning($"[AR] {mensaje}");
            Enviar(new EventoAR { evento = "error", mensaje = mensaje });
        }
    }
}
