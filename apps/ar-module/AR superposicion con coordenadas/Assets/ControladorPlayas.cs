using UnityEngine;
using UnityEngine.UI;
using UnityEngine.Networking;
using TMPro;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using TouristMAR.AR;

public class ControladorPlayas : MonoBehaviour
{
    [Header("UI 3D Flotante")]
    public TextMeshProUGUI textoTarjeta3D;
    public TextMeshProUGUI textoBoton;

    [Header("Estilo de la Tarjeta (tamaños en puntos)")]
    [Tooltip("Tamaño del nombre del lugar")]
    public int tamanoTitulo = 46;
    [Tooltip("Tamaño de la descripción")]
    public int tamanoCuerpo = 26;
    [Tooltip("Tamaño de la distancia / estado")]
    public int tamanoPie = 18;
    [Tooltip("Tamaño del texto del botón")]
    public int tamanoBoton = 20;
    [Tooltip("Espacio entre título y descripción")]
    public int espacioEntreBloques = 14;
    [Tooltip("Interlineado de la descripción (%)")]
    public int interlineadoCuerpo = 125;
    [Tooltip("Márgenes internos del texto: izquierda, arriba, derecha, abajo")]
    public Vector4 margenesTexto = new Vector4(36, 36, 36, 0);
    [Tooltip("Pone en mayúscula la primera letra de cada palabra del título")]
    public bool capitalizarTitulo = true;

    public Color colorTitulo = Color.white;
    public Color colorCuerpo = new Color32(0xD1, 0xD1, 0xD6, 0xFF);
    public Color colorPie = new Color32(0x8E, 0x8E, 0x93, 0xFF);
    public Color colorAcento = new Color32(0x4F, 0xD8, 0xE0, 0xFF); // cian "Estás aquí"

    [Header("Ajuste Automático del Fondo Visor")]
    public RectTransform fondoVisorRect;
    public float anchoFijo = 450f;
    public float espacioExtraParaBotonYMargen = 120f;

    [Header("Diseño Liquid Glass")]
    [Tooltip("Se agrega solo al fondo del visor si lo dejas vacío")]
    public VisorLiquidGlass visorGlass;
    [Tooltip("Aplica tamaños y colores del estilo Liquid Glass al iniciar. Desactívalo si quieres ajustarlos a mano en el Inspector.")]
    public bool usarPresetLiquidGlass = true;

    [Header("Configuración de API Externa")]
    [Tooltip("Usa la URL base sin ID al final para descargar todos los lugares creados en el admin")]
    public string urlApiPlayas = "https://touristmar-production.up.railway.app/api/ra/lugares";
    public bool cargarDesdeApiAlIniciar = true; 

    [Header("Configuración de Selección")]
    public string idPlayaSeleccionada = "ccdeddd5-59ad-49c0-85af-bb4aefa1958b"; // ID de Playa Las Palmitas por defecto

    [Header("Configuración GPS")]
    public float distanciaParaDetalle = 100f; 
    public bool usarGPSSimulado = true; 
    public double miLatitudSimulada = 19.119911; // Coordenadas simuladas para Playa Las Palmitas
    public double miLongitudSimulada = -104.37315;

    private bool mostrandoDetalle = true;
    
    // Lista de todos los lugares descargados desde la API
    private List<DatosLugarRA> lugaresDescargadosAPI = new List<DatosLugarRA>();
    private DatosLugarRA lugarActivoAPI; 
    private float distanciaActual;

    // Resguardo local en caso de estar offline
    private Playa playaActiva;

    [System.Serializable]
    public class Playa {
        public string id;           
        public string nombre;
        public double latitud;
        public double longitud;
        [TextArea(2, 4)] public string infoBasica;
        [TextArea(3, 6)] public string infoDetallada;
    }

    // Respaldo local: los IDs deben ser los mismos que devuelve la API (id del lugar, no del punto)
    private List<Playa> listaPlayasLocal = new List<Playa>() {
        new Playa {
            id = "f24442e4-6613-4427-99df-a7f962d6b99e",
            nombre = "Facultad de Ingeniería Electromecánica (FIE)",
            latitud = 19.12397051892223,
            longitud = -104.4000125955125,
            infoBasica = "Campus de la Universidad de Colima en El Naranjo. Centro de formación académica.",
            infoDetallada = "¡Bienvenido a la FIE - Universidad de Colima!\nCampus dedicado a la enseñanza e investigación en ingeniería electromecánica, mecatrónica y sistemas."
        },
        new Playa {
            id = "audiencia",
            nombre = "Playa La Audiencia",
            latitud = 19.104700,
            longitud = -104.350140,
            infoBasica = "Playa certificada, aguas cristalinas y arena fina. Ubicada en la Península.",
            infoDetallada = "¡Bienvenido a La Audiencia!\nGalardonada como Playa Limpia. El mejor lugar para hacer snorkel y nadar de forma segura."
        },
        new Playa {
            id = "miramar",
            nombre = "Playa Miramar",
            latitud = 19.118518,
            longitud = -104.386108,
            infoBasica = "El punto de encuentro por excelencia. Excelente oleaje para surf.",
            infoDetallada = "¡Bienvenido a Miramar!\nLa playa más popular. Su oleaje es ideal para deportes acuáticos y artesanías."
        }
    };


    void Awake()
    {
        PrepararVisorGlass();
        if (usarPresetLiquidGlass)
        {
            AplicarPresetLiquidGlass();
            // Si el fondo ya tiene Vertical Layout Group, su Padding hace de margen:
            // no sumamos otro margen al texto (si no, queda muy angosto).
            if (fondoVisorRect != null && fondoVisorRect.GetComponent<LayoutGroup>() != null)
                margenesTexto = Vector4.zero;
        }
        AplicarEstiloBase();
    }

    // ───────────────────────── LIQUID GLASS ─────────────────────────

    [ContextMenu("Aplicar preset Liquid Glass")]
    void AplicarPresetLiquidGlass()
    {
        // Escala tipográfica (ratio ~1.7 entre título y cuerpo)
        tamanoTitulo = 40;
        tamanoCuerpo = 23;
        tamanoPie = 14;          // categoría (eyebrow)
        tamanoBoton = 20;
        espacioEntreBloques = 12;
        interlineadoCuerpo = 130;
        margenesTexto = new Vector4(34, 30, 34, 0);

        colorTitulo = Color.white;
        colorCuerpo = new Color(1f, 1f, 1f, 0.78f);
        colorPie    = new Color(1f, 1f, 1f, 0.60f);
        colorAcento = new Color32(0x4F, 0xD8, 0xE0, 0xFF);
    }

    void PrepararVisorGlass()
    {
        Debug.Log("[LiquidGlass] ControladorPlayas NUEVO cargado. fondoVisorRect = " +
                  (fondoVisorRect != null ? fondoVisorRect.name : "VACÍO"));

        // Si no asignaste el fondo, usa el objeto con Image que contiene al texto
        if (fondoVisorRect == null && textoTarjeta3D != null)
        {
            Image img = textoTarjeta3D.transform.parent != null
                        ? textoTarjeta3D.transform.parent.GetComponentInParent<Image>() : null;
            if (img != null)
            {
                fondoVisorRect = img.rectTransform;
                Debug.LogWarning("[LiquidGlass] fondoVisorRect estaba vacío; se usará: " + img.name);
            }
        }

        if (visorGlass == null && fondoVisorRect != null)
        {
            visorGlass = fondoVisorRect.GetComponent<VisorLiquidGlass>();
            if (visorGlass == null) visorGlass = fondoVisorRect.gameObject.AddComponent<VisorLiquidGlass>();
        }
        if (visorGlass == null) return;

        if (visorGlass.tarjeta == null) visorGlass.tarjeta = fondoVisorRect;
        if (visorGlass.texto == null) visorGlass.texto = textoTarjeta3D;
        visorGlass.colorAcento = colorAcento;

        if (visorGlass.boton == null && textoBoton != null)
            visorGlass.boton = textoBoton.GetComponentInParent<Button>();
        if (visorGlass.textoBoton == null)
            visorGlass.textoBoton = textoBoton;
    }

    string CategoriaActiva()
    {
        if (lugarActivoAPI == null || string.IsNullOrWhiteSpace(lugarActivoAPI.categoria)) return "";
        return lugarActivoAPI.categoria.Trim().ToUpper(new CultureInfo("es-MX"));
    }

    void Start()
    {
        if (cargarDesdeApiAlIniciar)
        {
            StartCoroutine(ObtenerPlayasDesdeNUEVA_API_AndProcesar(idPlayaSeleccionada));
        }
        else
        {
            CargarYProcesarPlayaPorId(idPlayaSeleccionada);
        }
    }

    // ───────────────────────── ESTILO ─────────────────────────

    void AplicarEstiloBase()
    {
        if (textoTarjeta3D != null)
        {
            textoTarjeta3D.alignment = TextAlignmentOptions.TopLeft;
            textoTarjeta3D.overflowMode = TextOverflowModes.Overflow; // evita que corte con "..."
            textoTarjeta3D.margin = margenesTexto;
            textoTarjeta3D.richText = true;
        }

        if (textoBoton != null)
        {
            textoBoton.alignment = TextAlignmentOptions.Center;
            textoBoton.fontSize = tamanoBoton;
            textoBoton.fontStyle = FontStyles.Bold;
            textoBoton.color = Color.white;
        }
    }

    string Hex(Color c) => "#" + ColorUtility.ToHtmlStringRGBA(c);

    string FormatearTitulo(string titulo)
    {
        if (string.IsNullOrEmpty(titulo)) return "";
        if (!capitalizarTitulo) return titulo;
        // Solo corrige títulos escritos todo en minúsculas ("playa el viejo"),
        // así no se rompen siglas como "FIE".
        if (titulo != titulo.ToLower()) return titulo;
        return new CultureInfo("es-MX").TextInfo.ToTitleCase(titulo);
    }

    string FormatearDistancia(float metros)
    {
        if (metros >= 1000f)
            return (metros / 1000f).ToString("0.0", CultureInfo.InvariantCulture) + " km";
        return Mathf.RoundToInt(metros) + " m";
    }

    /// <summary>
    /// Texto de la tarjeta: CATEGORÍA (eyebrow) → Título → Descripción.
    /// El estado ("● Estás aquí") va en un chip aparte que dibuja VisorLiquidGlass.
    /// </summary>
    string ArmarTarjeta(string titulo, string cuerpo, string estado, Color? colorPunto)
    {
        string espacio = $"\n<size={espacioEntreBloques}>\n</size>";
        string resultado = "";

        // Sin VisorLiquidGlass: el estado va como texto (respaldo)
        if (visorGlass == null && !string.IsNullOrEmpty(estado))
        {
            Color punto = colorPunto ?? colorPie;
            resultado += $"<size={tamanoPie + 3}><color={Hex(punto)}>●</color><space=0.4em>" +
                         $"<color={Hex(colorPie)}>{estado}</color></size>" + espacio;
        }

        // Categoría en mayúsculas con tracking amplio
        string categoria = CategoriaActiva();
        if (!string.IsNullOrEmpty(categoria))
        {
            resultado += $"<size={tamanoPie}><b><cspace=0.14em><color={Hex(colorAcento)}>{categoria}</color></cspace></b></size>" +
                         $"\n<size={Mathf.Max(2, espacioEntreBloques / 2)}>\n</size>";
        }

        // Título: grande, compacto
        resultado += $"<size={tamanoTitulo}><line-height=108%><b><cspace=-0.01em><color={Hex(colorTitulo)}>" +
                     $"{FormatearTitulo(titulo)}</color></cspace></b></line-height></size>";

        // Descripción con interlineado cómodo
        if (!string.IsNullOrEmpty(cuerpo))
        {
            resultado += espacio +
                $"<size={tamanoCuerpo}><line-height={interlineadoCuerpo}%><color={Hex(colorCuerpo)}>{cuerpo}</color></line-height></size>";
        }

        return resultado;
    }

    /// <param name="botonActivo">true = botón de color (acción disponible); false = botón de vidrio atenuado</param>
    /// <param name="latido">true = el punto del chip late (estás en el lugar)</param>
    void MostrarTarjeta(string titulo, string cuerpo, string estado, string boton,
                        Color? colorPunto = null, bool botonActivo = false, bool latido = false)
    {
        if (textoTarjeta3D != null) textoTarjeta3D.text = ArmarTarjeta(titulo, cuerpo, estado, colorPunto);
        if (textoBoton != null) textoBoton.text = boton;
        if (visorGlass != null)
        {
            visorGlass.ActualizarEstado(estado, colorPunto ?? colorPie, latido);
            visorGlass.ActualizarBoton(botonActivo);
        }
        AjustarTamanoFondo();
    }

    string NombreActivo() => lugarActivoAPI != null ? lugarActivoAPI.nombre : (playaActiva != null ? playaActiva.nombre : "");

    // ───────────────────────── API ─────────────────────────

    public void EstablecerPlayaPorIdDesdeFlutter(string idPlaya)
    {
        CargarYProcesarPlayaPorId(idPlaya);
    }

    public IEnumerator ObtenerPlayasDesdeAPIAndProcesar(string idASeleccionar)
    {
        yield return StartCoroutine(ObtenerPlayasDesdeNUEVA_API_AndProcesar(idASeleccionar));
    }

    public IEnumerator ObtenerPlayasDesdeNUEVA_API_AndProcesar(string idASeleccionar)
    {
        MostrarTarjeta("Cargando…", "Obteniendo información de lugares.", "Conectando", "");

        string urlFinal = urlApiPlayas.Trim();

        using (UnityWebRequest webRequest = UnityWebRequest.Get(urlFinal))
        {
            yield return webRequest.SendWebRequest();

            if (webRequest.result == UnityWebRequest.Result.Success)
            {
                string jsonRecibido = webRequest.downloadHandler.text;
                Debug.Log("[API] JSON: " + jsonRecibido);
                lugaresDescargadosAPI.Clear();

                // 1. Intentamos leerlo como lista de múltiples lugares {"lugares": [...]}
                ListaLugaresAPI listaWrapper = JsonUtility.FromJson<ListaLugaresAPI>(jsonRecibido);
                if (listaWrapper != null && listaWrapper.lugares != null && listaWrapper.lugares.Length > 0)
                {
                    lugaresDescargadosAPI.AddRange(listaWrapper.lugares);
                    Debug.Log($"[API] Se descargaron {lugaresDescargadosAPI.Count} lugares de la base de datos.");
                }
                else
                {
                    // 2. Si no es lista, lo intentamos leer como objeto individual {"lugar": {...}}
                    RespuestaLugarAPI respuestaUnica = JsonUtility.FromJson<RespuestaLugarAPI>(jsonRecibido);
                    if (respuestaUnica != null && respuestaUnica.lugar != null)
                    {
                        lugaresDescargadosAPI.Add(respuestaUnica.lugar);
                        Debug.Log("[API] Se cargó 1 lugar específico: " + respuestaUnica.lugar.nombre);
                    }
                }
            }
            else
            {
                Debug.LogWarning("No se pudo conectar a la API. Usando respaldo local. Error: " + webRequest.error);
            }
        }

        CargarYProcesarPlayaPorId(idASeleccionar);
    }

    void CargarYProcesarPlayaPorId(string idPlaya)
    {
        idPlayaSeleccionada = idPlaya;
        mostrandoDetalle = true; // reinicia el estado al cambiar de lugar
        BuscarPlayaActivaPorId();

        if (lugarActivoAPI != null || playaActiva != null)
        {
            StopAllCoroutines();
            CancelInvoke("CalcularDistanciaALaPlaya");

            Debug.Log(lugarActivoAPI != null
                ? $"[RA] Lugar desde API: {lugarActivoAPI.nombre} ({lugarActivoAPI.id})"
                : $"[RA] Usando respaldo LOCAL: {playaActiva.nombre}");

            if (visorGlass != null) visorGlass.AnimarEntrada();
            MostrarTarjeta(NombreActivo(), null, "Obteniendo ubicación…", "Cargando…");
            StartCoroutine(IniciarGPSYTracking());
        }
        else
        {
            MostrarTarjeta("Ubicación no encontrada", "No se encontró el lugar con ID: " + idPlaya, null, "Error");
        }
    }

    void BuscarPlayaActivaPorId()
    {
        lugarActivoAPI = lugaresDescargadosAPI.Find(l => l.id == idPlayaSeleccionada);

        if (lugarActivoAPI != null)
            playaActiva = null;
        else
            playaActiva = listaPlayasLocal.Find(p => p.id == idPlayaSeleccionada);
    }

    // ───────────────────────── GPS ─────────────────────────

    IEnumerator IniciarGPSYTracking()
    {
        if (!usarGPSSimulado)
        {
            if (!Input.location.isEnabledByUser)
            {
                MostrarTarjeta(NombreActivo(), "Por favor activa el GPS de tu dispositivo.", null, "Sin GPS");
                yield break;
            }

            Input.location.Start(1f, 0.1f);

            int tiempoMaximoEspera = 20;
            while (Input.location.status == LocationServiceStatus.Initializing && tiempoMaximoEspera > 0)
            {
                yield return new WaitForSeconds(1);
                tiempoMaximoEspera--;
            }

            if (tiempoMaximoEspera < 1 || Input.location.status == LocationServiceStatus.Failed)
            {
                MostrarTarjeta(NombreActivo(), "No se pudo obtener la ubicación GPS actual.", null, "Reintentar");
                yield break;
            }
        }

        CalcularDistanciaALaPlaya();
        InvokeRepeating("CalcularDistanciaALaPlaya", 0.5f, 0.5f);
    }

    void CalcularDistanciaALaPlaya()
    {
        if (playaActiva == null && lugarActivoAPI == null) return;
        if (!usarGPSSimulado && Input.location.status != LocationServiceStatus.Running) return;

        double latActual = usarGPSSimulado ? miLatitudSimulada : Input.location.lastData.latitude;
        double lonActual = usarGPSSimulado ? miLongitudSimulada : Input.location.lastData.longitude;

        if (latActual == 0 && lonActual == 0 && !usarGPSSimulado) return; 

        double latDestino = 0;
        double lonDestino = 0;

        if (lugarActivoAPI != null)
        {
            bool tienePuntos = lugarActivoAPI.puntos != null && lugarActivoAPI.puntos.Length > 0;
            latDestino = tienePuntos ? lugarActivoAPI.puntos[0].latitud : lugarActivoAPI.latitud;
            lonDestino = tienePuntos ? lugarActivoAPI.puntos[0].longitud : lugarActivoAPI.longitud;
        }
        else if (playaActiva != null)
        {
            latDestino = playaActiva.latitud;
            lonDestino = playaActiva.longitud;
        }

        distanciaActual = CalcularDistanciaMatematica(latActual, lonActual, latDestino, lonDestino);
        ActualizarInterfaz();
    }

    float ObtenerRadioApertura()
    {
        float radioApertura = distanciaParaDetalle;
        if (lugarActivoAPI != null)
        {
            radioApertura = lugarActivoAPI.radioMetros > 0 ? lugarActivoAPI.radioMetros : distanciaParaDetalle;
            if (lugarActivoAPI.puntos != null && lugarActivoAPI.puntos.Length > 0 && lugarActivoAPI.puntos[0].radioVisible > 0)
                radioApertura = lugarActivoAPI.puntos[0].radioVisible;
        }
        return radioApertura;
    }

    // ───────────────────────── UI ─────────────────────────

    string Primero(params string[] opciones)
    {
        foreach (var s in opciones)
            if (!string.IsNullOrWhiteSpace(s)) return s.Trim();
        return "";
    }

    // textoParaMostrar viene como "Nombre\nDescripción": se le quita el nombre
    string SinTitulo(string texto, string nombre)
    {
        if (string.IsNullOrEmpty(texto)) return "";
        texto = texto.Trim();
        if (!string.IsNullOrEmpty(nombre) &&
            texto.StartsWith(nombre.Trim(), System.StringComparison.OrdinalIgnoreCase))
        {
            texto = texto.Substring(nombre.Trim().Length).TrimStart('\n', '\r', ' ');
        }
        return texto;
    }

    void ObtenerTextos(out string nombre, out string resumen, out string detalle)
    {
        nombre = resumen = detalle = "";

        if (lugarActivoAPI != null)
        {
            PuntoRA p = (lugarActivoAPI.puntos != null && lugarActivoAPI.puntos.Length > 0)
                        ? lugarActivoAPI.puntos[0] : null;
            string descripcion = SinTitulo(lugarActivoAPI.textoParaMostrar, lugarActivoAPI.nombre);

            nombre  = Primero(lugarActivoAPI.nombre, p?.titulo);
            // resumen/detalle del lugar primero; los del punto y textoParaMostrar
            // quedan de respaldo (APIs viejas sin esos campos).
            resumen = Primero(lugarActivoAPI.resumen, p?.resumen, descripcion, p?.detalle, lugarActivoAPI.direccion);
            detalle = Primero(lugarActivoAPI.detalle, p?.detalle, descripcion, p?.resumen, lugarActivoAPI.direccion);
        }
        else if (playaActiva != null)
        {
            nombre  = playaActiva.nombre;
            resumen = playaActiva.infoBasica;
            detalle = Primero(playaActiva.infoDetallada, playaActiva.infoBasica);
        }
    }

    void ActualizarInterfaz()
    {
        bool estoyEnElLugar = distanciaActual <= ObtenerRadioApertura();
        ObtenerTextos(out string nombre, out string resumen, out string detalle);
        Color puntoLejos = new Color(1f, 0.78f, 0.35f, 1f); // ámbar: "aún no llegas"

        if (estoyEnElLugar)
        {
            if (mostrandoDetalle)
            {
                MostrarTarjeta(nombre,
                    string.IsNullOrEmpty(detalle) ? "Este lugar aún no tiene descripción." : detalle,
                    "Estás aquí · " + FormatearDistancia(distanciaActual),
                    "Cerrar detalles", colorAcento, botonActivo: true, latido: true);
            }
            else
            {
                MostrarTarjeta(nombre, resumen, "Estás aquí", "Ver información",
                               colorAcento, botonActivo: true, latido: true);
            }
        }
        else
        {
            MostrarTarjeta(nombre, resumen,
                "A " + FormatearDistancia(distanciaActual) + " de ti",
                "Acércate para ver más", puntoLejos, botonActivo: false, latido: false);
        }
    }

    void AjustarTamanoFondo()
    {
        if (fondoVisorRect == null || textoTarjeta3D == null) return;
        textoTarjeta3D.ForceMeshUpdate();
        float alturaTexto = textoTarjeta3D.preferredHeight;
        fondoVisorRect.sizeDelta = new Vector2(anchoFijo, alturaTexto + espacioExtraParaBotonYMargen);
    }

    public void ToggleInformacion()
    {
        if (distanciaActual <= ObtenerRadioApertura())
        {
            mostrandoDetalle = !mostrandoDetalle;
            ActualizarInterfaz();
        }
    }

    float CalcularDistanciaMatematica(double lat1, double lon1, double lat2, double lon2)
    {
        float radioTierra = 6371000f;
        float dLat = (float)((lat2 - lat1) * Mathf.Deg2Rad);
        float dLon = (float)((lon2 - lon1) * Mathf.Deg2Rad);
        float a = Mathf.Sin(dLat / 2) * Mathf.Sin(dLat / 2) + Mathf.Cos((float)(lat1 * Mathf.Deg2Rad)) * Mathf.Cos((float)(lat2 * Mathf.Deg2Rad)) * Mathf.Sin(dLon / 2) * Mathf.Sin(dLon / 2);
        return radioTierra * 2 * Mathf.Atan2(Mathf.Sqrt(a), Mathf.Sqrt(1 - a));
    }

    // Permite ver los cambios de tamaño/color en vivo mientras juegas en el Editor
    void OnValidate()
    {
        if (Application.isPlaying)
        {
            AplicarEstiloBase();
            if (lugarActivoAPI != null || playaActiva != null) ActualizarInterfaz();
        }
    }
}