using UnityEngine;
using UnityEngine.UI;
using TMPro;

/// <summary>
/// Visor de RA estilo "Liquid Glass" (visionOS / iOS 26), generado 100% por código.
///
/// Estructura que arma dentro de FondoVisor (respeta tu Vertical Layout Group):
///   ┌──────────────────────────────────────┐
///   │ (● Estás aquí · 12 m)   ← chip       │
///   │ PLAYA                   ← categoría  │
///   │ Playa El Viejo          ← título     │
///   │ Descripción del lugar…  ← cuerpo     │
///   │ ──────────────────────  ← divisor    │
///   │ (     Ver información     ) ← botón  │
///   └──────────────────────────────────────┘
///
/// Capas del vidrio: sombra difusa · tinte translúcido · reflejo especular ·
/// brillo interno · borde que capta la luz arriba. Texturas en alta resolución.
/// </summary>
[DisallowMultipleComponent]
public class VisorLiquidGlass : MonoBehaviour
{
    [Header("Referencias (ControladorPlayas las llena solo)")]
    public RectTransform tarjeta;
    public TextMeshProUGUI texto;
    public Button boton;
    public TextMeshProUGUI textoBoton;

    [Header("Vidrio")]
    public Color tinte = new Color(0.08f, 0.09f, 0.10f, 0.70f);
    public float radioEsquinas = 40f;
    public Color colorBorde = new Color(1f, 1f, 1f, 0.45f);
    [Range(0f, 1f)] public float intensidadBordeAbajo = 0.15f;
    public Color colorBrillo = new Color(1f, 1f, 1f, 0.12f);
    public Color colorReflejo = new Color(1f, 1f, 1f, 0.06f);

    [Header("Sombra")]
    public bool usarSombra = true;
    public Color colorSombra = new Color(0f, 0f, 0f, 0.32f);
    public float tamanoSombra = 40f;
    public Vector2 desplazamientoSombra = new Vector2(0f, -16f);

    [Header("Chip de estado")]
    public int tamanoTextoChip = 16;
    public Color fondoChip = new Color(1f, 1f, 1f, 0.09f);
    public Color bordeChip = new Color(1f, 1f, 1f, 0.16f);
    public Color colorTextoChip = new Color(1f, 1f, 1f, 0.90f);

    [Header("Botón")]
    public Color colorAcento = new Color32(0x4F, 0xD8, 0xE0, 0xFF);
    public Color textoBotonActivo = new Color32(0x04, 0x22, 0x26, 0xFF);
    public Color fondoBotonInactivo = new Color(1f, 1f, 1f, 0.07f);
    public Color bordeBotonInactivo = new Color(1f, 1f, 1f, 0.20f);
    public Color textoBotonInactivo = new Color(1f, 1f, 1f, 0.55f);
    public float altoBoton = 58f;

    [Header("Divisor")]
    public bool usarDivisor = true;
    public Color colorDivisor = new Color(1f, 1f, 1f, 0.10f);

    [Header("Animación")]
    public bool animarEntrada = true;
    public float duracionEntrada = 0.45f;

    // Radio en píxeles de las texturas generadas (alta resolución)
    const int R = 128;

    // Medidas internas del chip
    const float PadIzqChip = 14f, PadDerChip = 16f, TamPunto = 9f, EspacioChip = 9f;
    float altoChip = 38f;
    RectTransform rtChip, rtTxtChip;

    Sprite spRelleno, spBordeLuz, spAnillo, spBrillo, spSombra, spReflejo;

    Image imgFondo, imgSombra, imgFondoBoton, imgBordeBoton, imgPunto, imgHalo;
    RectTransform rtSombra, rtHalo;
    GameObject filaEstado;
    TextMeshProUGUI txtChip;
    CanvasGroup grupo;
    Vector3 escalaBase = Vector3.one;

    bool construido;
    float tEntrada = 1f;

    // Estado pendiente (por si llega antes de construir)
    string estado = "";
    Color colorPunto = Color.white;
    bool pulso;
    bool botonActivo;

    // ───────────────────────── API pública ─────────────────────────

    /// <summary>Texto del chip superior. Vacío = ocultar chip.</summary>
    public void ActualizarEstado(string textoEstado, Color punto, bool latido)
    {
        estado = textoEstado ?? "";
        colorPunto = punto;
        pulso = latido;
        if (construido) AplicarEstado();
    }

    /// <summary>Activo = botón relleno de color; inactivo = botón de vidrio atenuado.</summary>
    public void ActualizarBoton(bool activo)
    {
        botonActivo = activo;
        if (construido) AplicarBoton();
    }

    public void AnimarEntrada()
    {
        if (animarEntrada) tEntrada = 0f;
    }

    // ───────────────────────── Ciclo de vida ─────────────────────────

    void Start() => Construir();

    void LateUpdate()
    {
        if (!construido) return;

        // Entrada: fade + escala + leve subida (ease-out cúbico)
        float e = 1f;
        if (tEntrada < 1f)
        {
            tEntrada += Time.deltaTime / Mathf.Max(0.01f, duracionEntrada);
            float t = Mathf.Clamp01(tEntrada);
            e = 1f - Mathf.Pow(1f - t, 3f);
            tarjeta.localScale = escalaBase * Mathf.Lerp(0.95f, 1f, e);
        }
        if (grupo != null) grupo.alpha = e;
        SincronizarSombra(e);

        // Punto de estado: "latido" cuando estás en el lugar
        if (rtHalo != null)
        {
            if (pulso)
            {
                float t = (Time.time * 0.8f) % 1f;
                rtHalo.localScale = Vector3.one * Mathf.Lerp(1f, 2.6f, t);
                Color c = colorPunto; c.a = 0.45f * (1f - t);
                imgHalo.color = c;
            }
            else
            {
                rtHalo.localScale = Vector3.one * 1.7f;
                Color c = colorPunto; c.a = 0.15f;
                imgHalo.color = c;
            }
        }
    }

    // ───────────────────────── Construcción ─────────────────────────

    void Construir()
    {
        if (construido) return;
        if (tarjeta == null) tarjeta = transform as RectTransform;
        if (tarjeta == null) { Debug.LogWarning("[LiquidGlass] Falta asignar 'tarjeta'."); return; }

        Canvas.ForceUpdateCanvases();
        GenerarSprites();
        escalaBase = tarjeta.localScale;

        // 1. Vidrio base
        imgFondo = tarjeta.GetComponent<Image>();
        if (imgFondo == null)
        {
            if (tarjeta.GetComponent<Graphic>() != null)
            {
                Debug.LogWarning("[LiquidGlass] El fondo tiene otro componente gráfico. Cámbialo por Image.");
                return;
            }
            imgFondo = tarjeta.gameObject.AddComponent<Image>();
        }
        ConfigurarSliced(imgFondo, spRelleno, radioEsquinas);
        imgFondo.color = tinte;

        // 2. Reflejo especular, brillo interno y borde de luz (no participan del layout)
        Image reflejo = CrearCapa("LG_Reflejo", tarjeta, 0, null, 0f, colorReflejo);
        reflejo.sprite = spReflejo;
        reflejo.type = Image.Type.Simple;
        CrearCapa("LG_Brillo", tarjeta, 1, spBrillo, radioEsquinas, colorBrillo);
        CrearCapa("LG_Borde", tarjeta, 2, spBordeLuz, radioEsquinas, colorBorde);

        // 3. Sombra (hermana anterior del fondo)
        if (usarSombra && tarjeta.parent != null)
        {
            var go = NuevoUI("LG_Sombra", tarjeta.parent, true);
            rtSombra = (RectTransform)go.transform;
            rtSombra.SetSiblingIndex(tarjeta.GetSiblingIndex());
            imgSombra = go.AddComponent<Image>();
            imgSombra.raycastTarget = false;
            ConfigurarSliced(imgSombra, spSombra, radioEsquinas + tamanoSombra);
            imgSombra.color = colorSombra;
        }

        grupo = tarjeta.GetComponent<CanvasGroup>();
        if (grupo == null) grupo = tarjeta.gameObject.AddComponent<CanvasGroup>();

        // 4. Chip de estado, arriba del texto
        ConstruirChip();

        // 5. Botón píldora + divisor
        ConstruirBoton();

        construido = true;
        AplicarEstado();
        AplicarBoton();
        Debug.Log($"[LiquidGlass] Diseño aplicado a '{tarjeta.name}'.");
        AnimarEntrada();
    }

    void ConstruirChip()
    {
        int indice = (texto != null && texto.transform.parent == tarjeta)
                     ? texto.transform.GetSiblingIndex() : tarjeta.childCount;

        // Fila de alto fijo dentro del Vertical Layout Group.
        // El chip se posiciona a mano (sin layouts anidados) para que mida exactamente su contenido.
        altoChip = Mathf.Round(tamanoTextoChip * 1.35f + 16f);
        filaEstado = NuevoUI("LG_FilaEstado", tarjeta, false);
        filaEstado.transform.SetSiblingIndex(indice);
        var leFila = filaEstado.AddComponent<LayoutElement>();
        leFila.minHeight = leFila.preferredHeight = altoChip;
        leFila.flexibleHeight = 0f;
        leFila.flexibleWidth = 1f;

        // Píldora anclada a la izquierda
        var chip = NuevoUI("LG_Chip", filaEstado.transform, false);
        rtChip = (RectTransform)chip.transform;
        rtChip.anchorMin = rtChip.anchorMax = new Vector2(0f, 0.5f);
        rtChip.pivot = new Vector2(0f, 0.5f);
        rtChip.anchoredPosition = Vector2.zero;
        rtChip.sizeDelta = new Vector2(120f, altoChip);
        var imgChip = chip.AddComponent<Image>();
        imgChip.raycastTarget = false;
        ConfigurarSliced(imgChip, spRelleno, altoChip * 0.5f);
        imgChip.color = fondoChip;
        CrearCapa("LG_BordeChip", rtChip, 0, spAnillo, altoChip * 0.5f, bordeChip);

        // Punto + halo
        var punto = NuevoUI("LG_Punto", chip.transform, false);
        var rtPunto = (RectTransform)punto.transform;
        rtPunto.anchorMin = rtPunto.anchorMax = new Vector2(0f, 0.5f);
        rtPunto.pivot = new Vector2(0.5f, 0.5f);
        rtPunto.anchoredPosition = new Vector2(PadIzqChip + TamPunto * 0.5f, 0f);
        rtPunto.sizeDelta = new Vector2(TamPunto, TamPunto);
        imgPunto = punto.AddComponent<Image>();
        imgPunto.raycastTarget = false;
        ConfigurarSliced(imgPunto, spRelleno, 4.5f);

        var halo = NuevoUI("LG_Halo", punto.transform, true);
        rtHalo = (RectTransform)halo.transform;
        rtHalo.anchorMin = rtHalo.anchorMax = new Vector2(0.5f, 0.5f);
        rtHalo.sizeDelta = new Vector2(9f, 9f);
        rtHalo.SetAsFirstSibling();
        imgHalo = halo.AddComponent<Image>();
        imgHalo.raycastTarget = false;
        ConfigurarSliced(imgHalo, spRelleno, 4.5f);

        // Texto del chip
        var goTxt = NuevoUI("LG_TextoChip", chip.transform, false);
        rtTxtChip = (RectTransform)goTxt.transform;
        rtTxtChip.anchorMin = rtTxtChip.anchorMax = new Vector2(0f, 0.5f);
        rtTxtChip.pivot = new Vector2(0f, 0.5f);
        rtTxtChip.anchoredPosition = new Vector2(PadIzqChip + TamPunto + EspacioChip, 0f);
        txtChip = goTxt.AddComponent<TextMeshProUGUI>();
        if (texto != null) txtChip.font = texto.font;
        txtChip.fontSize = tamanoTextoChip;
        txtChip.fontStyle = FontStyles.Bold;
        txtChip.characterSpacing = 2f;
        txtChip.color = colorTextoChip;
        txtChip.textWrappingMode = TextWrappingModes.NoWrap;
        txtChip.alignment = TextAlignmentOptions.MidlineLeft;
        txtChip.raycastTarget = false;
    }

    void ConstruirBoton()
    {
        if (boton == null) return;

        imgFondoBoton = boton.targetGraphic as Image;
        if (textoBoton == null) textoBoton = boton.GetComponentInChildren<TextMeshProUGUI>();

        // Alto fijo dentro del layout
        var le = boton.GetComponent<LayoutElement>();
        if (le == null) le = boton.gameObject.AddComponent<LayoutElement>();
        le.minHeight = le.preferredHeight = altoBoton;

        if (imgFondoBoton != null)
        {
            ConfigurarSliced(imgFondoBoton, spRelleno, altoBoton * 0.5f);
            imgBordeBoton = CrearCapa("LG_BordeBoton", imgFondoBoton.rectTransform, 0,
                                      spAnillo, altoBoton * 0.5f, bordeBotonInactivo);
        }

        // El color lo controlamos nosotros; el botón solo oscurece al presionar
        var colores = boton.colors;
        colores.normalColor = colores.highlightedColor = colores.selectedColor = Color.white;
        colores.pressedColor = new Color(0.80f, 0.80f, 0.80f, 1f);
        colores.disabledColor = Color.white;
        colores.fadeDuration = 0.08f;
        boton.colors = colores;

        // Divisor fino entre el contenido y el botón
        if (usarDivisor && boton.transform.parent == tarjeta)
        {
            var div = NuevoUI("LG_Divisor", tarjeta, false);
            div.transform.SetSiblingIndex(boton.transform.GetSiblingIndex());
            var leDiv = div.AddComponent<LayoutElement>();
            leDiv.minHeight = leDiv.preferredHeight = 1f;
            leDiv.flexibleWidth = 1f;
            var img = div.AddComponent<Image>();
            img.raycastTarget = false;
            img.color = colorDivisor;
        }
    }

    void AplicarEstado()
    {
        if (filaEstado == null) return;
        bool visible = !string.IsNullOrEmpty(estado);
        if (filaEstado.activeSelf != visible) filaEstado.SetActive(visible);
        if (!visible) return;
        txtChip.text = estado;
        imgPunto.color = colorPunto;

        // El chip mide exactamente su contenido
        float anchoTexto = Mathf.Ceil(txtChip.GetPreferredValues(estado).x) + 2f;
        rtTxtChip.sizeDelta = new Vector2(anchoTexto, altoChip);
        rtChip.sizeDelta = new Vector2(PadIzqChip + TamPunto + EspacioChip + anchoTexto + PadDerChip, altoChip);
    }

    void AplicarBoton()
    {
        if (imgFondoBoton != null)
            imgFondoBoton.color = botonActivo ? colorAcento : fondoBotonInactivo;
        if (imgBordeBoton != null)
            imgBordeBoton.color = botonActivo ? new Color(1f, 1f, 1f, 0.35f) : bordeBotonInactivo;
        if (textoBoton != null)
        {
            textoBoton.color = botonActivo ? textoBotonActivo : textoBotonInactivo;
            textoBoton.fontStyle = FontStyles.Bold;
            textoBoton.characterSpacing = 1f;
        }
    }

    // ───────────────────────── Utilidades ─────────────────────────

    static GameObject NuevoUI(string nombre, Transform padre, bool ignorarLayout)
    {
        var go = new GameObject(nombre, typeof(RectTransform));
        go.layer = padre.gameObject.layer;
        go.transform.SetParent(padre, false);
        if (ignorarLayout) go.AddComponent<LayoutElement>().ignoreLayout = true;
        return go;
    }

    Image CrearCapa(string nombre, RectTransform padre, int indice, Sprite sprite, float radio, Color color)
    {
        var go = NuevoUI(nombre, padre, true);
        var rt = (RectTransform)go.transform;
        rt.SetSiblingIndex(indice);
        rt.anchorMin = Vector2.zero;
        rt.anchorMax = Vector2.one;
        rt.offsetMin = rt.offsetMax = Vector2.zero;
        var img = go.AddComponent<Image>();
        img.raycastTarget = false;
        if (sprite != null) ConfigurarSliced(img, sprite, radio);
        img.color = color;
        return img;
    }

    void ConfigurarSliced(Image img, Sprite sprite, float radioUI)
    {
        img.sprite = sprite;
        img.type = Image.Type.Sliced;
        img.fillCenter = true;
        float refPPU = img.canvas != null ? img.canvas.referencePixelsPerUnit : 100f;
        // La esquina del sprite medirá exactamente 'radioUI' unidades
        img.pixelsPerUnitMultiplier = sprite.border.x * refPPU / (sprite.pixelsPerUnit * Mathf.Max(0.5f, radioUI));
    }

    void SincronizarSombra(float alfa)
    {
        if (rtSombra == null) return;
        rtSombra.anchorMin = tarjeta.anchorMin;
        rtSombra.anchorMax = tarjeta.anchorMax;
        rtSombra.pivot = tarjeta.pivot;
        rtSombra.sizeDelta = tarjeta.sizeDelta + Vector2.one * (2f * tamanoSombra);
        rtSombra.anchoredPosition = tarjeta.anchoredPosition + desplazamientoSombra
                                    + (tarjeta.pivot * 2f - Vector2.one) * tamanoSombra;
        rtSombra.localRotation = tarjeta.localRotation;
        rtSombra.localScale = tarjeta.localScale;
        Color c = colorSombra; c.a *= alfa;
        imgSombra.color = c;
    }

    // ───────────────────────── Texturas (alta resolución) ─────────────────────────

    void GenerarSprites()
    {
        float abajo = intensidadBordeAbajo;

        // Relleno con antialiasing
        spRelleno = CrearRedondeado((d, v) => 0.5f - d);

        // Borde de ~1.2 unidades que capta la luz arriba y se apaga abajo
        spBordeLuz = CrearRedondeado((d, v) =>
            Mathf.Clamp01(0.5f - d) * Mathf.Clamp01(d + 4.5f) *
            Mathf.Lerp(1f, abajo, Mathf.SmoothStep(0f, 1f, v)));

        // Borde uniforme (chip y botón)
        spAnillo = CrearRedondeado((d, v) => Mathf.Clamp01(0.5f - d) * Mathf.Clamp01(d + 4.5f));

        // Brillo interno pegado al borde, más intenso arriba
        spBrillo = CrearRedondeado((d, v) =>
        {
            if (d > 0.5f) return 0f;
            float g = Mathf.Clamp01(1f + d / 40f);
            return Mathf.Pow(g, 2.4f) * Mathf.Clamp01(0.5f - d) * Mathf.Lerp(1f, 0.1f, v);
        });

        // Sombra difusa
        spSombra = CrearRedondeado((d, v) =>
        {
            float t = Mathf.Clamp01(-d / R);
            return t * t * (3f - 2f * t);
        });

        spReflejo = CrearReflejo();
    }

    /// <param name="alfa">(distancia al borde en px, vertical 0=arriba..1=abajo) → alfa</param>
    static Sprite CrearRedondeado(System.Func<float, float, float> alfa)
    {
        int S = 2 * R + 2;
        var tex = new Texture2D(S, S, TextureFormat.RGBA32, false)
        {
            wrapMode = TextureWrapMode.Clamp,
            filterMode = FilterMode.Bilinear,
            anisoLevel = 0
        };

        var px = new Color32[S * S];
        float c = S * 0.5f;
        float h = S * 0.5f - 1f;

        for (int y = 0; y < S; y++)
        {
            for (int x = 0; x < S; x++)
            {
                float qx = Mathf.Abs(x + 0.5f - c) - (h - R);
                float qy = Mathf.Abs(y + 0.5f - c) - (h - R);
                float fuera = new Vector2(Mathf.Max(qx, 0f), Mathf.Max(qy, 0f)).magnitude;
                float dentro = Mathf.Min(Mathf.Max(qx, qy), 0f);
                float d = fuera + dentro - R;
                float v = 1f - (y + 0.5f) / S;
                px[y * S + x] = new Color(1f, 1f, 1f, Mathf.Clamp01(alfa(d, v)));
            }
        }

        tex.SetPixels32(px);
        tex.Apply(false, true);
        float b = R + 1;
        return Sprite.Create(tex, new Rect(0, 0, S, S), new Vector2(0.5f, 0.5f), 100f, 0,
                             SpriteMeshType.FullRect, new Vector4(b, b, b, b));
    }

    /// <summary>Reflejo de luz suave arriba a la izquierda (se desvanece antes de las orillas).</summary>
    static Sprite CrearReflejo()
    {
        const int S = 256;
        var tex = new Texture2D(S, S, TextureFormat.RGBA32, false)
        {
            wrapMode = TextureWrapMode.Clamp,
            filterMode = FilterMode.Bilinear
        };
        var px = new Color32[S * S];
        for (int y = 0; y < S; y++)
        {
            for (int x = 0; x < S; x++)
            {
                float u = (x + 0.5f) / S;
                float v = 1f - (y + 0.5f) / S;
                float dx = (u - 0.30f) / 0.34f;
                float dy = (v - 0.16f) / 0.16f;
                float a = Mathf.Exp(-(dx * dx + dy * dy) * 1.6f);
                float orilla = Mathf.Clamp01(Mathf.Min(Mathf.Min(u, 1f - u), Mathf.Min(v, 1f - v)) * 10f);
                px[y * S + x] = new Color(1f, 1f, 1f, a * orilla);
            }
        }
        tex.SetPixels32(px);
        tex.Apply(false, true);
        return Sprite.Create(tex, new Rect(0, 0, S, S), new Vector2(0.5f, 0.5f), 100f);
    }
}