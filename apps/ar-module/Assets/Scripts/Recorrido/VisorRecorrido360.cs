using System.Collections;
using System.Collections.Generic;
using TMPro;
using TouristMAR.AR;
using UnityEngine;
using UnityEngine.Networking;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.EnhancedTouch;
using Touch = UnityEngine.InputSystem.EnhancedTouch.Touch;
#endif

namespace TouristMAR.Recorrido
{
    /// <summary>
    /// Visor del recorrido 360° por escenarios (escena "Recorrido"). Es el
    /// mismo visor que el de Flutter (apps/web/lib/widgets/recorrido360/visor_360.dart):
    /// misma API, misma convención de ángulos y mismo diseño, así el turista ve
    /// lo mismo en la web, en el panel del admin y en el teléfono.
    ///
    /// Flujo: la app abre la actividad de Unity con los extras "escena" =
    /// "recorrido", "parametro" = nombre del recorrido y "apiBaseUrl" (ver
    /// MainActivity.kt) → GET {apiBaseUrl}/recorridos/{nombre} → arranca en
    /// <c>escenaInicial</c> mirando hacia su <c>yawInicial</c> → cada flecha
    /// lleva al escenario <c>destino</c> (por id).
    ///
    /// Ángulos (grados), iguales al backend y a Flutter: yaw -180…180, 0 = el
    /// centro horizontal de la foto equirectangular y positivo hacia la
    /// derecha (yaw = (u − 0.5)·360, con u = x / ancho); pitch -90…90, 0 = el
    /// horizonte y negativo hacia el piso. Si al probar la cámara no arranca
    /// mirando al centro de la foto, ajusta <see cref="ajusteYaw"/> (ver README).
    /// </summary>
    public class VisorRecorrido360 : MonoBehaviour
    {
        [Header("Datos (solo Editor / build suelto: en el teléfono vienen de la app)")]
        [Tooltip("API en el 5173 (http://<IP-de-la-PC>:5173/api). En el teléfono la manda la app en el extra 'apiBaseUrl'.")]
        [SerializeField] private string apiBaseUrlPorDefecto = "http://localhost:5173/api";
        [Tooltip("Nombre del recorrido a cargar en el Editor (ej. fime_explanada_360).")]
        [SerializeField] private string recorridoPorDefecto = "";

        [Header("Escena")]
        [SerializeField] private Camera camara;
        [Tooltip("Material con el shader Skybox/Panoramic (Mapping: Latitude Longitude Layout, Image Type: 360 Degrees).")]
        [SerializeField] private Material materialPanoramico;
        [SerializeField] private FlechaRecorrido360 prefabFlecha;
        [SerializeField] private float distanciaFlechas = 4f;
        [Tooltip("Calibración única: grados que se suman al yaw del backend para que yaw 0 caiga en el centro de la foto.")]
        [SerializeField] private float ajusteYaw;

        [Header("Controles (mismos límites que el visor de Flutter)")]
        [SerializeField] private float sensibilidad = 0.15f;
        [SerializeField] private float fovInicial = 75f;
        [Tooltip("Las fotos de 1280×640 se ven borrosas con más acercamiento.")]
        [SerializeField] private float fovMinimo = 40f;
        [SerializeField] private float fovMaximo = 90f;

        [Header("Interfaz (mismo diseño que la app)")]
        [SerializeField] private TMP_Text textoTitulo;
        [Tooltip("\"Explanada · 1 de 16\"")]
        [SerializeField] private TMP_Text textoEscena;
        [SerializeField] private GameObject panelDescripcion;
        [SerializeField] private TMP_Text textoDescripcion;
        [Tooltip("Negro a pantalla completa para el fundido entre escenarios.")]
        [SerializeField] private CanvasGroup fundido;
        [SerializeField] private GameObject indicadorCargando;

        private string apiBaseUrl;
        private DatosRecorrido360 recorrido;
        private readonly Dictionary<string, DatosEscena360> porId = new();
        private readonly Dictionary<string, Texture2D> texturas = new();
        private readonly List<FlechaRecorrido360> flechas = new();
        private string actualId;
        private float yaw;
        private float pitch;
        private bool cambiando;

        // Gestos
        private Vector2? ultimoPuntero;
        private float arrastreTotal;
        private float? distanciaPellizco;

        private void OnEnable()
        {
#if ENABLE_INPUT_SYSTEM
            EnhancedTouchSupport.Enable();
#endif
        }

        private IEnumerator Start()
        {
            if (camara == null) camara = Camera.main;
            camara.fieldOfView = fovInicial;
            camara.clearFlags = CameraClearFlags.Skybox;
            RenderSettings.skybox = materialPanoramico;

            apiBaseUrl = (ExtraDeLaApp("apiBaseUrl") ?? apiBaseUrlPorDefecto).TrimEnd('/');
            var nombre = ExtraDeLaApp("parametro") ?? recorridoPorDefecto;
            if (string.IsNullOrEmpty(nombre))
            {
                MostrarError("No se indicó qué recorrido abrir.");
                yield break;
            }
            yield return CargarRecorrido(nombre);
        }

        // --- Datos ------------------------------------------------------------

        private IEnumerator CargarRecorrido(string nombre)
        {
            Cargando(true);
            using var req = UnityWebRequest.Get($"{apiBaseUrl}/recorridos/{UnityWebRequest.EscapeURL(nombre)}");
            yield return req.SendWebRequest();
            if (req.result != UnityWebRequest.Result.Success)
            {
                MostrarError(req.responseCode == 404
                    ? "Este recorrido ya no está disponible."
                    : "No se pudo cargar el recorrido. Revisa tu conexión.");
                yield break;
            }

            recorrido = JsonUtility.FromJson<RespuestaRecorrido>(req.downloadHandler.text)?.recorrido;
            if (recorrido == null || recorrido.escenas == null || recorrido.escenas.Length == 0)
            {
                MostrarError("Este recorrido todavía no tiene escenarios.");
                yield break;
            }
            porId.Clear();
            foreach (var e in recorrido.escenas) porId[e.id] = e;

            if (textoTitulo != null) textoTitulo.text = recorrido.textoParaMostrar.Split('\n')[0];
            var inicial = porId.ContainsKey(recorrido.escenaInicial) ? recorrido.escenaInicial : recorrido.escenas[0].id;
            yield return IrA(inicial);
        }

        private IEnumerator Textura(DatosEscena360 escena)
        {
            if (texturas.ContainsKey(escena.id)) yield break;
            // nonReadable: la textura vive solo en la GPU (no se duplica en RAM).
            using var req = UnityWebRequestTexture.GetTexture(escena.urlImagen, true);
            yield return req.SendWebRequest();
            if (req.result != UnityWebRequest.Result.Success)
            {
                Debug.LogWarning($"[Recorrido] No se pudo bajar {escena.urlImagen}: {req.error}");
                yield break;
            }
            var tex = DownloadHandlerTexture.GetContent(req);
            // Repeat en horizontal para que no se vea la costura al dar la vuelta.
            tex.wrapModeU = TextureWrapMode.Repeat;
            tex.wrapModeV = TextureWrapMode.Clamp;
            tex.filterMode = FilterMode.Bilinear;
            tex.anisoLevel = 4;
            texturas[escena.id] = tex;
        }

        // --- Navegación -------------------------------------------------------

        /// <summary>Pasa a otro escenario (lo llaman las flechas o la tira de escenarios).</summary>
        public void IrAEscenario(string id)
        {
            if (!cambiando && id != actualId && porId.ContainsKey(id)) StartCoroutine(IrA(id));
        }

        /// <summary>Para botones de una tira de escenarios: 0 = el primero.</summary>
        public void IrAEscenarioIndice(int indice)
        {
            if (recorrido != null && indice >= 0 && indice < recorrido.escenas.Length) IrAEscenario(recorrido.escenas[indice].id);
        }

        private IEnumerator IrA(string id)
        {
            cambiando = true;
            var escena = porId[id];
            if (actualId != null) yield return Fundido(1f);

            Cargando(true);
            yield return Textura(escena);
            Cargando(false);
            if (!texturas.TryGetValue(id, out var tex))
            {
                MostrarError("No se pudo cargar este escenario.");
                yield return Fundido(0f);
                cambiando = false;
                yield break;
            }

            materialPanoramico.SetTexture("_MainTex", tex);
            actualId = id;
            yaw = escena.yawInicial;
            pitch = 0;
            camara.fieldOfView = fovInicial;
            AplicarVista();
            PintarFlechas(escena);
            PintarTextos(escena);

            yield return Fundido(0f);
            cambiando = false;

            LiberarLejanas(escena);
            // Precarga de los escenarios vecinos: el siguiente salto es inmediato.
            if (escena.enlaces != null)
                foreach (var enlace in escena.enlaces)
                    if (porId.TryGetValue(enlace.destino, out var vecino)) yield return Textura(vecino);
        }

        /// <summary>
        /// Una foto de 4096×2048 ocupa ~32 MB en la GPU. Se quedan solo la actual
        /// y sus vecinas.
        /// </summary>
        private void LiberarLejanas(DatosEscena360 actual)
        {
            var conservar = new HashSet<string> { actual.id };
            if (actual.enlaces != null) foreach (var e in actual.enlaces) conservar.Add(e.destino);
            var borrar = new List<string>();
            foreach (var par in texturas) if (!conservar.Contains(par.Key)) borrar.Add(par.Key);
            foreach (var clave in borrar)
            {
                Destroy(texturas[clave]);
                texturas.Remove(clave);
            }
        }

        private void PintarFlechas(DatosEscena360 escena)
        {
            foreach (var f in flechas) Destroy(f.gameObject);
            flechas.Clear();
            if (escena.enlaces == null) return;
            foreach (var enlace in escena.enlaces)
            {
                if (!porId.ContainsKey(enlace.destino)) continue;
                var flecha = Instantiate(prefabFlecha, Direccion(enlace.yaw, enlace.pitch) * distanciaFlechas, Quaternion.identity, transform);
                // El backend ya rellena la etiqueta con el título del destino si el admin no puso una.
                flecha.Configurar(enlace.destino, enlace.etiqueta, camara);
                flechas.Add(flecha);
            }
        }

        private void PintarTextos(DatosEscena360 escena)
        {
            var indice = System.Array.IndexOf(recorrido.escenas, escena) + 1;
            if (textoEscena != null) textoEscena.text = $"{escena.titulo} · {indice} de {recorrido.escenas.Length}";
            var hayDescripcion = !string.IsNullOrEmpty(escena.descripcion);
            if (panelDescripcion != null) panelDescripcion.SetActive(hayDescripcion);
            if (textoDescripcion != null) textoDescripcion.text = escena.descripcion;
        }

        /// <summary>"Volver a la vista inicial" (mismo botón que el visor de la app).</summary>
        public void VistaInicial()
        {
            if (actualId == null) return;
            yaw = porId[actualId].yawInicial;
            pitch = 0;
            AplicarVista();
        }

        /// <summary>Botón "atrás": cierra Unity y vuelve a la ficha del lugar en la app.</summary>
        public void Salir() => Application.Quit();

        // --- Cámara y gestos ---------------------------------------------------

        private Quaternion Rotacion(float yawGrados, float pitchGrados) =>
            Quaternion.Euler(-pitchGrados, yawGrados + ajusteYaw, 0f);

        private Vector3 Direccion(float yawGrados, float pitchGrados) => Rotacion(yawGrados, pitchGrados) * Vector3.forward;

        private void AplicarVista()
        {
            pitch = Mathf.Clamp(pitch, -85f, 85f);
            camara.transform.SetPositionAndRotation(Vector3.zero, Rotacion(yaw, pitch));
        }

        private void Update()
        {
            if (AtrasPresionado()) Salir();
            if (recorrido == null || cambiando) return;

            // Pellizco (dos dedos) o rueda del mouse: acercar / alejar.
            var pellizco = DistanciaPellizco();
            if (pellizco.HasValue)
            {
                if (distanciaPellizco.HasValue) Zoom((distanciaPellizco.Value - pellizco.Value) * 0.1f);
                distanciaPellizco = pellizco;
                ultimoPuntero = null;
                arrastreTotal = 999f; // un pellizco nunca cuenta como toque
                return;
            }
            distanciaPellizco = null;
            Zoom(-RuedaMouse() * 5f);

            // Arrastrar: la foto sigue al dedo, como en Street View.
            if (Puntero(out var posicion))
            {
                if (ultimoPuntero.HasValue)
                {
                    var delta = posicion - ultimoPuntero.Value;
                    arrastreTotal += delta.magnitude;
                    var escala = sensibilidad * camara.fieldOfView / fovInicial;
                    yaw -= delta.x * escala;
                    pitch -= delta.y * escala;
                    AplicarVista();
                }
                else
                {
                    arrastreTotal = 0f;
                }
                ultimoPuntero = posicion;
            }
            else if (ultimoPuntero.HasValue)
            {
                // Soltó sin arrastrar: fue un toque → ¿tocó una flecha?
                if (arrastreTotal < 12f) TocarEn(ultimoPuntero.Value);
                ultimoPuntero = null;
            }
        }

        private void Zoom(float delta)
        {
            if (Mathf.Approximately(delta, 0f)) return;
            camara.fieldOfView = Mathf.Clamp(camara.fieldOfView + delta, fovMinimo, fovMaximo);
        }

        private void TocarEn(Vector2 pantalla)
        {
            var rayo = camara.ScreenPointToRay(pantalla);
            if (Physics.Raycast(rayo, out var golpe, distanciaFlechas * 2f) &&
                golpe.collider.GetComponentInParent<FlechaRecorrido360>() is { } flecha)
            {
                IrAEscenario(flecha.Destino);
            }
        }

        // --- Entrada (Input System nuevo o el clásico, según el proyecto) ------

        private static bool Puntero(out Vector2 posicion)
        {
#if ENABLE_INPUT_SYSTEM
            if (Touch.activeTouches.Count == 1)
            {
                posicion = Touch.activeTouches[0].screenPosition;
                return true;
            }
            if (Touch.activeTouches.Count == 0 && Mouse.current != null && Mouse.current.leftButton.isPressed)
            {
                posicion = Mouse.current.position.ReadValue();
                return true;
            }
#else
            if (Input.touchCount == 1)
            {
                posicion = Input.GetTouch(0).position;
                return true;
            }
            if (Input.touchCount == 0 && Input.GetMouseButton(0))
            {
                posicion = Input.mousePosition;
                return true;
            }
#endif
            posicion = default;
            return false;
        }

        private static float? DistanciaPellizco()
        {
#if ENABLE_INPUT_SYSTEM
            if (Touch.activeTouches.Count < 2) return null;
            return Vector2.Distance(Touch.activeTouches[0].screenPosition, Touch.activeTouches[1].screenPosition);
#else
            if (Input.touchCount < 2) return null;
            return Vector2.Distance(Input.GetTouch(0).position, Input.GetTouch(1).position);
#endif
        }

        private static float RuedaMouse()
        {
#if ENABLE_INPUT_SYSTEM
            return Mouse.current != null ? Mouse.current.scroll.ReadValue().y / 120f : 0f;
#else
            return Input.mouseScrollDelta.y;
#endif
        }

        private static bool AtrasPresionado()
        {
#if ENABLE_INPUT_SYSTEM
            return Keyboard.current != null && Keyboard.current.escapeKey.wasPressedThisFrame;
#else
            return Input.GetKeyDown(KeyCode.Escape);
#endif
        }

        // --- Interfaz ----------------------------------------------------------

        private IEnumerator Fundido(float destino)
        {
            if (fundido == null) yield break;
            var inicio = fundido.alpha;
            for (var t = 0f; t < 1f; t += Time.deltaTime / 0.2f)
            {
                fundido.alpha = Mathf.Lerp(inicio, destino, t);
                yield return null;
            }
            fundido.alpha = destino;
        }

        private void Cargando(bool activo)
        {
            if (indicadorCargando != null) indicadorCargando.SetActive(activo);
        }

        private void MostrarError(string mensaje)
        {
            Cargando(false);
            Debug.LogWarning($"[Recorrido] {mensaje}");
            if (textoEscena != null) textoEscena.text = mensaje;
        }

        /// <summary>
        /// Lee un extra del Intent con el que la app abrió Unity (MainActivity.kt).
        /// En el Editor devuelve null y se usan los valores por defecto. Si ya
        /// tienen ParametrosApp.cs, pueden usar ese en su lugar.
        /// </summary>
        private static string ExtraDeLaApp(string clave)
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            using var unity = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
            using var actividad = unity.GetStatic<AndroidJavaObject>("currentActivity");
            using var intent = actividad.Call<AndroidJavaObject>("getIntent");
            var valor = intent.Call<string>("getStringExtra", clave);
            return string.IsNullOrEmpty(valor) ? null : valor;
#else
            return null;
#endif
        }

        private void OnDestroy()
        {
            foreach (var tex in texturas.Values) Destroy(tex);
            texturas.Clear();
        }
    }
}
