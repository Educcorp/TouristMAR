using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEngine;
using UnityEngine.Networking;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARSubsystems;

namespace TouristMAR.AR
{
    /// <summary>
    /// Descarga los marcadores que dan de alta los admins, los agrega a la
    /// biblioteca de rastreo en tiempo de ejecución y muestra la información
    /// encima de cada imagen detectada.
    ///
    /// Va como componente en el GameObject "XR Origin", junto al
    /// ARTrackedImageManager (cuya Serialized Library debe ser LibreriaBase, con
    /// "Keep Texture at Runtime" activado). No arranca solo: lo inicia
    /// PuenteApp cuando recibe la configuración de la app anfitriona.
    /// </summary>
    [RequireComponent(typeof(ARTrackedImageManager))]
    public class MarcadorDinamico : MonoBehaviour
    {
        [Tooltip("LibreriaBase (Keep Texture at Runtime activado). Puede estar vacía o traer marcadores fijos.")]
        [SerializeField] private XRReferenceImageLibrary libreriaBase;

        [Tooltip("Prefab con InfoMarcadorUI que aparece encima de cada marcador.")]
        [SerializeField] private InfoMarcadorUI prefabInfo;

        [Tooltip("Guarda las imágenes descargadas en el teléfono para no bajarlas en cada apertura.")]
        [SerializeField] private bool usarCache = true;

        private ARTrackedImageManager manager;
        private MutableRuntimeReferenceImageLibrary biblioteca;
        private ConfigAR config;
        private PuenteApp puente;

        // Contenido por nombre de imagen (= id del marcador). Se refresca en cada
        // recarga, así los cambios de texto se ven sin reiniciar.
        private readonly Dictionary<string, DatosMarcador> contenidos = new();
        // Imágenes ya agregadas a la biblioteca. Una biblioteca mutable no permite
        // quitar ni reemplazar imágenes, así que si un admin cambia la imagen de
        // un marcador, la nueva se usa en la siguiente sesión de AR.
        private readonly HashSet<string> registrados = new();
        private readonly Dictionary<TrackableId, InfoMarcadorUI> instancias = new();
        // Para registrar el escaneo (y avisar a la app) una sola vez por sesión.
        private readonly HashSet<string> detectados = new();

        private Coroutine carga;

        private void Awake()
        {
            manager = GetComponent<ARTrackedImageManager>();
        }

        private void OnEnable()
        {
            manager.trackablesChanged.AddListener(OnCambiosDeImagenes);
        }

        private void OnDisable()
        {
            manager.trackablesChanged.RemoveListener(OnCambiosDeImagenes);
        }

        /// <summary>Punto de entrada: lo llama PuenteApp con la config de la app.</summary>
        public void Iniciar(ConfigAR nuevaConfig, PuenteApp puenteApp)
        {
            config = nuevaConfig;
            puente = puenteApp;
            Recargar();
        }

        /// <summary>Vuelve a pedir la lista (marcadores nuevos o textos editados).</summary>
        public void Recargar()
        {
            if (config == null) return;
            if (carga != null) StopCoroutine(carga);
            carga = StartCoroutine(CargarMarcadores());
        }

        private IEnumerator CargarMarcadores()
        {
            // La biblioteca solo se puede modificar con la sesión AR ya creada.
            while (ARSession.state < ARSessionState.SessionInitializing)
            {
                if (ARSession.state == ARSessionState.Unsupported)
                {
                    puente?.EnviarError("Este dispositivo no es compatible con realidad aumentada");
                    yield break;
                }
                yield return null;
            }

            if (!PrepararBiblioteca()) yield break;

            ListaDesdeAdmin lista = null;
            using (var req = UnityWebRequest.Get($"{config.apiBaseUrl.TrimEnd('/')}/ar/marcadores"))
            {
                yield return req.SendWebRequest();
                if (req.result != UnityWebRequest.Result.Success)
                {
                    puente?.EnviarError($"No se pudieron obtener los marcadores: {req.error}");
                    yield break;
                }
                lista = JsonUtility.FromJson<ListaDesdeAdmin>(req.downloadHandler.text);
            }

            contenidos.Clear();
            if (lista?.marcadores == null) lista = new ListaDesdeAdmin { marcadores = new DatosMarcador[0] };

            foreach (var marcador in lista.marcadores)
            {
                contenidos[marcador.id] = marcador;
            }

            // Uno por uno: son pocos y así no se satura la red del teléfono.
            foreach (var marcador in lista.marcadores)
            {
                if (registrados.Contains(marcador.id)) continue;
                yield return RegistrarMarcador(marcador);
            }

            // Refresca las tarjetas que ya estén en pantalla (por si cambió el texto).
            foreach (var par in instancias)
            {
                if (manager.trackables.TryGetTrackable(par.Key, out var imagen) &&
                    contenidos.TryGetValue(imagen.referenceImage.name, out var datos))
                {
                    par.Value.Mostrar(datos);
                }
            }

            puente?.Enviar(new EventoAR { evento = "marcadoresCargados", total = registrados.Count });
            carga = null;
        }

        private bool PrepararBiblioteca()
        {
            if (biblioteca != null) return true;

            if (manager.referenceLibrary is MutableRuntimeReferenceImageLibrary mutable)
            {
                biblioteca = mutable;
                return true;
            }

            if (manager.descriptor == null || !manager.descriptor.supportsMutableLibrary)
            {
                puente?.EnviarError("Este dispositivo no permite agregar marcadores en tiempo de ejecución");
                return false;
            }

            // Parte de LibreriaBase (vacía o con marcadores fijos) y la vuelve mutable.
            biblioteca = manager.CreateRuntimeLibrary(libreriaBase) as MutableRuntimeReferenceImageLibrary;
            manager.referenceLibrary = biblioteca;
            return biblioteca != null;
        }

        private IEnumerator RegistrarMarcador(DatosMarcador marcador)
        {
            byte[] bytes = null;
            var rutaCache = RutaCache(marcador.imagenUrl);

            if (usarCache && File.Exists(rutaCache))
            {
                bytes = File.ReadAllBytes(rutaCache);
            }
            else
            {
                using var req = UnityWebRequest.Get(marcador.imagenUrl);
                yield return req.SendWebRequest();
                if (req.result != UnityWebRequest.Result.Success)
                {
                    Debug.LogWarning($"[AR] No se pudo descargar la imagen de '{marcador.nombre}': {req.error}");
                    yield break;
                }
                bytes = req.downloadHandler.data;
                if (usarCache) GuardarCache(rutaCache, bytes);
            }

            // LoadImage deja la textura legible (requisito para la biblioteca).
            var textura = new Texture2D(2, 2);
            if (!textura.LoadImage(bytes))
            {
                Debug.LogWarning($"[AR] La imagen de '{marcador.nombre}' no es un PNG/JPG válido");
                yield break;
            }
            textura = AsegurarFormato(textura);

            float? ancho = marcador.anchoMetros > 0 ? marcador.anchoMetros : null;
            var trabajo = biblioteca.ScheduleAddImageWithValidationJob(textura, marcador.id, ancho);
            yield return new WaitUntil(() => trabajo.jobHandle.IsCompleted);
            trabajo.jobHandle.Complete();

            if (trabajo.status == AddReferenceImageJobStatus.Success)
            {
                registrados.Add(marcador.id);
            }
            else
            {
                // Típicamente ErrorInvalidImage: imagen con poco detalle/contraste
                // (ver guía de imágenes en apps/ar-module/README.md).
                Debug.LogWarning($"[AR] '{marcador.nombre}' no se pudo usar como marcador: {trabajo.status}");
            }
        }

        private Texture2D AsegurarFormato(Texture2D textura)
        {
            if (biblioteca.IsTextureFormatSupported(textura.format)) return textura;

            var convertida = new Texture2D(textura.width, textura.height, TextureFormat.RGBA32, false);
            convertida.SetPixels32(textura.GetPixels32());
            convertida.Apply();
            Destroy(textura);
            return convertida;
        }

        private void OnCambiosDeImagenes(ARTrackablesChangedEventArgs<ARTrackedImage> args)
        {
            foreach (var imagen in args.added) Actualizar(imagen);
            foreach (var imagen in args.updated) Actualizar(imagen);
            foreach (var par in args.removed)
            {
                if (instancias.TryGetValue(par.Key, out var ui))
                {
                    if (ui != null) Destroy(ui.gameObject);
                    instancias.Remove(par.Key);
                }
            }
        }

        private void Actualizar(ARTrackedImage imagen)
        {
            var nombre = imagen.referenceImage.name;
            if (!contenidos.TryGetValue(nombre, out var datos)) return;

            if (!instancias.TryGetValue(imagen.trackableId, out var ui))
            {
                ui = Instantiate(prefabInfo, imagen.transform);
                ui.Mostrar(datos);
                instancias[imagen.trackableId] = ui;
            }

            // En "Limited" la imagen suele estar fuera de cuadro (ARKit la sigue
            // reportando); ocultar evita tarjetas flotando en el vacío.
            var visible = imagen.trackingState == TrackingState.Tracking;
            ui.SetVisible(visible);

            if (visible && detectados.Add(nombre))
            {
                puente?.Enviar(new EventoAR
                {
                    evento = "marcadorDetectado",
                    marcadorId = datos.id,
                    titulo = datos.titulo,
                    negocioId = datos.negocioId,
                });
                StartCoroutine(RegistrarEscaneo(datos.id));
            }
        }

        private IEnumerator RegistrarEscaneo(string marcadorId)
        {
            var cuerpo = JsonUtility.ToJson(new EscaneoBody { plataforma = Plataforma() });
            using var req = new UnityWebRequest($"{config.apiBaseUrl.TrimEnd('/')}/ar/marcadores/{marcadorId}/escaneo", "POST")
            {
                uploadHandler = new UploadHandlerRaw(Encoding.UTF8.GetBytes(cuerpo)),
                downloadHandler = new DownloadHandlerBuffer(),
            };
            req.SetRequestHeader("Content-Type", "application/json");
            if (!string.IsNullOrEmpty(config.token)) req.SetRequestHeader("Authorization", $"Bearer {config.token}");
            // Las estadísticas no deben interrumpir la experiencia: si falla, se ignora.
            yield return req.SendWebRequest();
        }

        [System.Serializable]
        private class EscaneoBody
        {
            public string plataforma;
        }

        private static string Plataforma()
        {
#if UNITY_EDITOR
            return "editor";
#elif UNITY_IOS
            return "ios";
#else
            return "android";
#endif
        }

        private static string RutaCache(string url)
        {
            // La URL trae ?v=<timestamp>: si el admin reemplaza la imagen, cambia
            // el hash y se descarga la nueva.
            var dir = Path.Combine(Application.persistentDataPath, "ar-marcadores");
            return Path.Combine(dir, Hash128.Compute(url).ToString());
        }

        private static void GuardarCache(string ruta, byte[] bytes)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(ruta));
                File.WriteAllBytes(ruta, bytes);
            }
            catch (IOException e)
            {
                Debug.LogWarning($"[AR] No se pudo guardar en caché: {e.Message}");
            }
        }
    }
}
