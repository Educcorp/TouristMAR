using UnityEngine;
using UnityEngine.UI;
using TMPro;

// Visor AR TouristMAR — estilo Liquid Glass (Apple, 2025-26).
// Principios: cámara a pantalla completa, vidrio desenfocado y claro,
// filos finos que captan la luz, sin reflejos "brillosos", tipografía limpia.
[DefaultExecutionOrder(1000)]
[RequireComponent(typeof(RectTransform))]
public class VisorARResponsive : MonoBehaviour
{
    [Header("Objetos de la escena")]
    public RectTransform bordeSuperior;
    public RectTransform bordeInferior;
    public RectTransform bordeIzquierdo;
    public RectTransform bordeDerecho;
    public RectTransform textoTitulo;
    public RectTransform textoInfo;

    [Header("Instrucción")]
    [TextArea] public string instruccion = "Apunta la cámara al marcador";

    [Header("Tipografía (Font Assets de TMP — recomendado: Inter)")]
    public TMP_FontAsset fuenteTitulos;   // Inter SemiBold
    public TMP_FontAsset fuenteTexto;     // Inter Regular
    public float tamanoTitulo = 54f;
    public float tamanoTextoInfo = 40f;
    public float tamanoEtiqueta = 30f;

    [Header("Tarjeta")]
    [Range(0.25f, 0.65f)] public float proporcionTarjeta = 0.45f;

    [Header("Vidrio")]
    public Color vidrioCuerpo          = new Color32(14, 16, 22, 140);    // vidrio oscuro translúcido
    public Color vidrioFilo            = new Color32(255, 255, 255, 70);  // filo que capta la luz
    public Color vidrioAcento          = new Color32(99, 230, 226, 255);  // menta (estilo Apple)
    public Color vidrioTexto           = new Color32(255, 255, 255, 255);
    public Color vidrioTextoSecundario = new Color32(235, 240, 245, 210);

    // ---------------- Internos ----------------
    const float SUAVE = 20f;
    const float BORDE_BASE = 121.5f;
    static Sprite spriteBase, spriteSuave, spriteFilo, spriteEsquina, spriteDegradado;

    class Vidrio { public RectTransform raiz; public Image sombra, cuerpo, filo; }

    bool construido, detectado;
    float progreso = -1f, segundosRestantes;
    float k, lado, centroX, centroY, escalaRecuadro = 1f;
    float vistaH, suavizadoTexto, etiquetaH;
    Color colorEsquinas = Color.white;
    string tituloGuardado, infoGuardada, textoMedido;

    // Para detectar cambios de tamaño y reacomodar
    Vector2 tamUltimo;
    Vector2Int pantallaUltima;
    Rect safeUltimo;
    bool reportado;
    float titX, titY, titW, titH;

    Vidrio pildora, tarjeta;
    TMP_Text tmpTitulo, tmpInfo, tmpInstruccion, tmpEtiqueta;
    RectTransform vineta, vista, etiqueta, punto, riel, rellenoRiel;
    Image imgPunto, imgRiel, imgRellenoRiel;
    ScrollRect scroll;
    RectMask2D mascara;
    RectTransform[] esquinas = new RectTransform[4];
    Image[] esquinasImg = new Image[4];

    // ================= API pública (la usa MarcadorConMemoria) =================
    public void SetTextos(string titulo, string info)
    {
        BuscarTextos();
        if (tmpTitulo != null) tmpTitulo.text = titulo;
        if (tmpInfo != null) tmpInfo.text = info;
        tituloGuardado = titulo;
        infoGuardada = info;
    }

    public void SetDetectado(bool valor) { detectado = valor; }

    public void SetProgreso(float p, float segundos = 0f)
    {
        progreso = p;
        segundosRestantes = segundos;
    }

    // ================= Ciclo de vida =================
    void Start()
    {
        BuscarTextos();
        AsegurarCanvasOverlay();
        Construir();
        construido = true;
        ConfigurarVisor();
    }

    void BuscarTextos()
    {
        if (tmpTitulo == null && textoTitulo != null) tmpTitulo = textoTitulo.GetComponent<TMP_Text>();
        if (tmpInfo == null && textoInfo != null) tmpInfo = textoInfo.GetComponent<TMP_Text>();
    }

    // En AR el Canvas DEBE ser Overlay: AR Foundation cambia la proyección de la cámara
    // y un Canvas en modo Camera se deforma o desaparece.
    void AsegurarCanvasOverlay()
    {
        var canvas = GetComponentInParent<Canvas>();
        if (canvas == null) return;
        canvas = canvas.rootCanvas;
        if (canvas.renderMode != RenderMode.ScreenSpaceOverlay)
        {
            Debug.LogWarning("[Visor] El Canvas estaba en '" + canvas.renderMode + "'. Lo cambio a Screen Space - Overlay (necesario en AR).");
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            Canvas.ForceUpdateCanvases(); // que el tamaño del Canvas se actualice ya
        }
    }

#if UNITY_EDITOR
    void OnValidate()
    {
        UnityEditor.EditorApplication.delayCall += () => { if (this != null) ConfigurarVisor(); };
    }
#endif

    void OnRectTransformDimensionsChange()
    {
        if (isActiveAndEnabled) ConfigurarVisor();
    }

    void Update()
    {
        if (!construido) return;
        float dt = Time.deltaTime;

        // Recuadro: "respira" muy suave mientras busca; se cierra un poco al detectar
        float escalaObj = detectado ? 0.93f : 1f + 0.015f * Mathf.Sin(Time.time * 2.2f);
        escalaRecuadro = Mathf.Lerp(escalaRecuadro, escalaObj, dt * 8f);
        if (lado > 0f) AcomodarEsquinas();

        Color objetivo = detectado ? vidrioAcento : new Color(1f, 1f, 1f, 0.9f);
        colorEsquinas = Color.Lerp(colorEsquinas, objetivo, dt * 8f);
        foreach (var img in esquinasImg) img.color = colorEsquinas;

        // Etiqueta de estado: punto de color + texto
        bool enMemoria = !detectado && progreso >= 0f;
        Color colPunto;
        if (detectado)
        {
            tmpEtiqueta.text = "Marcador detectado";
            colPunto = vidrioAcento;
        }
        else if (enMemoria)
        {
            tmpEtiqueta.text = "Se oculta en " + Mathf.CeilToInt(segundosRestantes) + " s";
            colPunto = vidrioAcento;
        }
        else
        {
            tmpEtiqueta.text = "Buscando marcador";
            colPunto = new Color(1f, 1f, 1f, 0.35f + 0.65f * (0.5f + 0.5f * Mathf.Sin(Time.time * 3.5f)));
        }
        imgPunto.color = Color.Lerp(imgPunto.color, colPunto, dt * 12f);

        // Barra de tiempo
        riel.gameObject.SetActive(enMemoria);
        if (enMemoria) rellenoRiel.anchorMax = new Vector2(Mathf.Clamp01(progreso), 1f);
    }

    // Corre al final del frame, después de tu script de la API
    void LateUpdate()
    {
        if (!construido) return;
        BuscarTextos();
        if (tmpTitulo == null || tmpInfo == null) return;

        // 1) Si cambió el tamaño del Canvas, la pantalla o la zona segura → reacomodar todo
        RectTransform canvasRect = (RectTransform)transform;
        if (canvasRect.rect.size != tamUltimo ||
            pantallaUltima != new Vector2Int(Screen.width, Screen.height) ||
            Screen.safeArea != safeUltimo)
            ConfigurarVisor();

        // 2) Si otro script movió u ocultó los textos, los regresamos a su lugar
        if (!textoTitulo.gameObject.activeSelf) textoTitulo.gameObject.SetActive(true);
        if (!textoInfo.gameObject.activeSelf) textoInfo.gameObject.SetActive(true);
        if (textoTitulo.parent != transform) textoTitulo.SetParent(transform, false);
        if (titW > 0f) Colocar(textoTitulo, titX, titY, titW, titH);
        if (textoInfo.parent != vista) textoInfo.SetParent(vista, false);
        textoInfo.anchorMin = new Vector2(0f, 1f);
        textoInfo.anchorMax = new Vector2(1f, 1f);
        textoInfo.pivot = new Vector2(0.5f, 1f);
        textoInfo.localScale = Vector3.one;
        textoInfo.anchoredPosition = new Vector2(0f, textoInfo.anchoredPosition.y);
        textoInfo.sizeDelta = new Vector2(0f, textoInfo.sizeDelta.y);

        // 3) Memoria de 10 s
        if (detectado)
        {
            if (!string.IsNullOrEmpty(tmpTitulo.text)) tituloGuardado = tmpTitulo.text;
            if (!string.IsNullOrEmpty(tmpInfo.text)) infoGuardada = tmpInfo.text;
        }
        else if (progreso >= 0f)
        {
            if (tituloGuardado != null && tmpTitulo.text != tituloGuardado) tmpTitulo.text = tituloGuardado;
            if (infoGuardada != null && tmpInfo.text != infoGuardada) tmpInfo.text = infoGuardada;
        }

        AplicarEstiloTextos();

        if (tmpInfo.text != textoMedido)
        {
            textoMedido = tmpInfo.text;
            MedirTexto(true);
        }
    }

    // ================= Construcción =================
    void Construir()
    {
        foreach (var b in new[] { bordeSuperior, bordeInferior, bordeIzquierdo, bordeDerecho })
            if (b != null) b.gameObject.SetActive(false);

        // Solo una viñeta muy ligera abajo para dar contraste a la tarjeta
        vineta = NuevaImagen("Vineta", transform, SpriteDegradado(), new Color(0f, 0f, 0f, 0.28f), false).rectTransform;
        vineta.SetAsFirstSibling();

        for (int i = 0; i < 4; i++)
        {
            esquinasImg[i] = NuevaImagen("EsquinaEscaneo" + i, transform, SpriteEsquina(), Color.white, false);
            esquinas[i] = esquinasImg[i].rectTransform;
        }

        pildora = CrearVidrio("PildoraInstruccion", transform);
        tmpInstruccion = CrearTexto("Instruccion", pildora.raiz, TextAlignmentOptions.Center);
        Anclar(tmpInstruccion.rectTransform);

        tarjeta = CrearVidrio("TarjetaVidrio", transform);

        etiqueta = NuevoRect("EtiquetaEstado", transform);
        imgPunto = NuevaImagen("Punto", etiqueta, SpriteBase(), Color.white, true);
        punto = imgPunto.rectTransform;
        punto.anchorMin = punto.anchorMax = new Vector2(0f, 0.5f);
        punto.pivot = new Vector2(0f, 0.5f);
        tmpEtiqueta = CrearTexto("TextoEstado", etiqueta, TextAlignmentOptions.MidlineLeft);
        Anclar(tmpEtiqueta.rectTransform);

        if (textoTitulo != null) textoTitulo.SetAsLastSibling();

        var imgVista = NuevaImagen("VistaInfo", transform, null, new Color(1f, 1f, 1f, 0f), false);
        imgVista.raycastTarget = true;
        vista = imgVista.rectTransform;
        mascara = vista.gameObject.AddComponent<RectMask2D>();

        if (textoInfo != null && tmpInfo != null)
        {
            textoInfo.SetParent(vista, false);
            textoInfo.anchorMin = new Vector2(0f, 1f);
            textoInfo.anchorMax = new Vector2(1f, 1f);
            textoInfo.pivot = new Vector2(0.5f, 1f);
            textoInfo.anchoredPosition = Vector2.zero;
            textoInfo.sizeDelta = new Vector2(0f, textoInfo.sizeDelta.y);

            var ajuste = textoInfo.GetComponent<ContentSizeFitter>();
            if (ajuste == null) ajuste = textoInfo.gameObject.AddComponent<ContentSizeFitter>();
            ajuste.horizontalFit = ContentSizeFitter.FitMode.Unconstrained;
            ajuste.verticalFit = ContentSizeFitter.FitMode.PreferredSize;

            scroll = vista.gameObject.AddComponent<ScrollRect>();
            scroll.content = textoInfo;
            scroll.viewport = vista;
            scroll.horizontal = false;
            scroll.vertical = true;
            scroll.movementType = ScrollRect.MovementType.Clamped;
            scroll.scrollSensitivity = 30f;
        }

        imgRiel = NuevaImagen("RielTiempo", transform, SpriteBase(), new Color(1f, 1f, 1f, 0.16f), true);
        riel = imgRiel.rectTransform;
        imgRellenoRiel = NuevaImagen("RellenoTiempo", riel, SpriteBase(), vidrioAcento, true);
        rellenoRiel = imgRellenoRiel.rectTransform;
        Anclar(rellenoRiel);

        AplicarEstiloTextos();
    }

    Vidrio CrearVidrio(string nombre, Transform padre)
    {
        var v = new Vidrio { raiz = NuevoRect(nombre, padre) };

        // Sombra amplia y casi imperceptible (solo separa del fondo)
        v.sombra = NuevaImagen("Sombra", v.raiz, SpriteSuave(), new Color(0f, 0f, 0f, 0.14f), true);
        Estirar(v.sombra.rectTransform, new Vector2(-SUAVE, -SUAVE - 10f), new Vector2(SUAVE, SUAVE - 10f));

        // Cuerpo: vidrio oscuro translúcido (se ve la cámara detrás, el texto se lee)
        v.cuerpo = NuevaImagen("Cuerpo", v.raiz, SpriteBase(), vidrioCuerpo, true);
        Estirar(v.cuerpo.rectTransform, Vector2.zero, Vector2.zero);

        // Filo: línea fina, más brillante en las esquinas superior-izquierda e inferior-derecha
        v.filo = NuevaImagen("Filo", v.raiz, SpriteFilo(), vidrioFilo, true);
        v.filo.fillCenter = false;
        Estirar(v.filo.rectTransform, Vector2.zero, Vector2.zero);
        return v;
    }

    static void RedondearVidrio(Vidrio v, float radio)
    {
        Redondear(v.cuerpo, radio);
        Redondear(v.filo, radio);
    }

    void AplicarEstiloTextos()
    {
        Estilo(tmpInstruccion, fuenteTitulos, vidrioTexto, true, 0f);
        Estilo(tmpEtiqueta, fuenteTitulos, vidrioTextoSecundario, true, 0.3f);
        if (tmpTitulo != null)
        {
            Estilo(tmpTitulo, fuenteTitulos, vidrioTexto, true, -1f);
            tmpTitulo.alignment = TextAlignmentOptions.BottomLeft;
            tmpTitulo.enableAutoSizing = true;
            tmpTitulo.overflowMode = TextOverflowModes.Ellipsis;
        }
        if (tmpInfo != null)
        {
            Estilo(tmpInfo, fuenteTexto, vidrioTextoSecundario, false, 0f);
            tmpInfo.alignment = TextAlignmentOptions.TopLeft;
            tmpInfo.enableAutoSizing = false;
            tmpInfo.overflowMode = TextOverflowModes.Overflow;
            tmpInfo.lineSpacing = 10f;
            tmpInfo.paragraphSpacing = 8f;
        }
    }

    void Estilo(TMP_Text t, TMP_FontAsset fuente, Color color, bool fuerte, float espaciado)
    {
        if (t == null) return;
        if (fuente != null && t.font != fuente) t.font = fuente;
        t.fontStyle = (fuerte && fuente == null) ? FontStyles.Bold : FontStyles.Normal;
        t.color = color;
        t.characterSpacing = espaciado;
        t.raycastTarget = false;
    }

    // ================= Acomodo =================
    void ConfigurarVisor()
    {
        if (!construido) return;
        RectTransform canvasRect = (RectTransform)transform;
        float w = canvasRect.rect.width, h = canvasRect.rect.height;
        if (w <= 0f || h <= 0f || Screen.height <= 0) return;

        k = w / 1080f;
        float escala = h / Screen.height;
        Rect sa = Screen.safeArea;
        float insetArriba = (Screen.height - sa.yMax) * escala;
        float insetAbajo = sa.yMin * escala;
        float m = 28f * k;

        // Viñeta inferior
        Colocar(vineta, 0f, 0f, w, h * 0.5f);

        // Píldora de instrucción
        string textoInstr = instruccion.Replace("\n", " ").Trim();
        tmpInstruccion.fontSize = 30f * k;
        tmpInstruccion.text = textoInstr;
        float pilH = 88f * k;
        float pilW = Mathf.Min(w - 2f * m - 40f * k, tmpInstruccion.GetPreferredValues(textoInstr).x + 96f * k);
        float pilY = h - insetArriba - 20f * k - pilH;
        Colocar(pildora.raiz, (w - pilW) / 2f, pilY, pilW, pilH);
        RedondearVidrio(pildora, pilH / 2f);

        // Tarjeta
        float cardX = m, cardW = w - 2f * m;
        float cardY = insetAbajo + 20f * k;
        // La tarjeta nunca se come el espacio del recuadro de escaneo
        float disponible = pilY - cardY;
        float cardMax = Mathf.Max(260f * k, disponible - 420f * k);
        float cardH = Mathf.Clamp(disponible * proporcionTarjeta, 260f * k, cardMax);
        Colocar(tarjeta.raiz, cardX, cardY, cardW, cardH);
        RedondearVidrio(tarjeta, 76f * k);
        float pad = 56f * k;

        // Etiqueta de estado
        etiquetaH = 44f * k;
        float etiY = cardY + cardH - pad - etiquetaH;
        Colocar(etiqueta, cardX + pad, etiY, cardW - 2f * pad, etiquetaH);
        float diam = 14f * k;
        punto.anchoredPosition = Vector2.zero;
        punto.sizeDelta = new Vector2(diam, diam);
        Redondear(imgPunto, diam / 2f);
        tmpEtiqueta.fontSize = tamanoEtiqueta * k;
        tmpEtiqueta.rectTransform.offsetMin = new Vector2(diam + 16f * k, 0f);

        // Título
        float titH = 76f * k;
        float titY = etiY - 14f * k - titH;
        this.titX = cardX + pad; this.titY = titY; this.titW = cardW - 2f * pad; this.titH = titH;
        if (textoTitulo != null) Colocar(textoTitulo, this.titX, titY, this.titW, titH);
        if (tmpTitulo != null) { tmpTitulo.fontSizeMax = tamanoTitulo * k; tmpTitulo.fontSizeMin = 38f * k; }

        // Barra de tiempo
        float rielH = 5f * k, rielY = cardY + 40f * k;
        Colocar(riel, cardX + pad, rielY, cardW - 2f * pad, rielH);
        Redondear(imgRiel, 2.5f * k);
        Redondear(imgRellenoRiel, 2.5f * k);

        // Descripción
        if (tmpInfo != null) tmpInfo.fontSize = tamanoTextoInfo * k;
        float vistaY = rielY + rielH + 24f * k;
        vistaH = Mathf.Max(0f, titY - 18f * k - vistaY);
        Colocar(vista, cardX + pad, vistaY, cardW - 2f * pad, vistaH);
        suavizadoTexto = 44f * k;

        // Recuadro de escaneo
        float areaArriba = pilY - 48f * k, areaAbajo = cardY + cardH + 48f * k;
        float areaH = Mathf.Max(0f, areaArriba - areaAbajo);
        lado = Mathf.Min(w * 0.64f, areaH * 0.8f);
        centroX = w / 2f;
        centroY = areaAbajo + areaH / 2f;
        AcomodarEsquinas();

        MedirTexto(false);

        tamUltimo = canvasRect.rect.size;
        pantallaUltima = new Vector2Int(Screen.width, Screen.height);
        safeUltimo = Screen.safeArea;

        if (!reportado)
        {
            reportado = true;
            var c = GetComponentInParent<Canvas>();
            Debug.Log($"[Visor] Canvas {w:0}x{h:0} ({(c != null ? c.rootCanvas.renderMode.ToString() : "sin Canvas")}) | " +
                      $"Pantalla {Screen.width}x{Screen.height} | Zona segura {sa} | k={k:0.00} | " +
                      $"tarjeta alto={cardH:0} | recuadro={lado:0}");
        }
    }

    void AcomodarEsquinas()
    {
        float l = lado * escalaRecuadro;
        float x0 = centroX - l / 2f, y0 = centroY - l / 2f;
        float largo = 88f * k;
        Vector2[] p = { new Vector2(x0, y0), new Vector2(x0 + l, y0), new Vector2(x0, y0 + l), new Vector2(x0 + l, y0 + l) };
        for (int i = 0; i < 4; i++)
        {
            Colocar(esquinas[i], p[i].x, p[i].y, largo, largo);
            esquinas[i].localScale = Giro(i);
        }
    }

    void MedirTexto(bool volverArriba)
    {
        if (tmpInfo == null || vista == null) return;
        tmpInfo.margin = Vector4.zero;
        float textoW = vista.rect.width;
        float alto = (string.IsNullOrEmpty(tmpInfo.text) || textoW <= 0f) ? 0f
                     : tmpInfo.GetPreferredValues(tmpInfo.text, textoW, 0f).y;

        bool hayMas = alto > vistaH + 2f;
        if (scroll != null) scroll.enabled = hayMas;
        int s = Mathf.RoundToInt(suavizadoTexto);
        mascara.softness = hayMas ? new Vector2Int(0, s) : Vector2Int.zero;
        if (hayMas) tmpInfo.margin = new Vector4(0f, 0f, 0f, s);
        if (volverArriba || !hayMas) textoInfo.anchoredPosition = Vector2.zero;
    }

    static Vector3 Giro(int i) => new Vector3(i % 2 == 0 ? 1f : -1f, i < 2 ? 1f : -1f, 1f);

    // ================= Utilidades =================
    static RectTransform NuevoRect(string nombre, Transform padre)
    {
        var go = new GameObject(nombre, typeof(RectTransform));
        go.transform.SetParent(padre, false);
        return (RectTransform)go.transform;
    }

    static Image NuevaImagen(string nombre, Transform padre, Sprite sprite, Color color, bool rebanada)
    {
        var go = new GameObject(nombre, typeof(RectTransform), typeof(Image));
        go.transform.SetParent(padre, false);
        var img = go.GetComponent<Image>();
        img.sprite = sprite;
        img.type = rebanada ? Image.Type.Sliced : Image.Type.Simple;
        img.color = color;
        img.raycastTarget = false;
        return img;
    }

    static TMP_Text CrearTexto(string nombre, Transform padre, TextAlignmentOptions alineacion)
    {
        var go = new GameObject(nombre, typeof(RectTransform), typeof(TextMeshProUGUI));
        go.transform.SetParent(padre, false);
        var t = go.GetComponent<TextMeshProUGUI>();
        t.alignment = alineacion;
        t.raycastTarget = false;
        return t;
    }

    static void Colocar(RectTransform r, float x, float y, float ancho, float alto)
    {
        r.anchorMin = Vector2.zero;
        r.anchorMax = Vector2.zero;
        r.pivot = Vector2.zero;
        r.anchoredPosition = new Vector2(x, y);
        r.sizeDelta = new Vector2(ancho, alto);
    }

    static void Anclar(RectTransform r)
    {
        r.anchorMin = Vector2.zero;
        r.anchorMax = Vector2.one;
        r.offsetMin = Vector2.zero;
        r.offsetMax = Vector2.zero;
    }

    static void Estirar(RectTransform r, Vector2 offsetMin, Vector2 offsetMax)
    {
        r.anchorMin = Vector2.zero;
        r.anchorMax = Vector2.one;
        r.offsetMin = offsetMin;
        r.offsetMax = offsetMax;
    }

    static void Redondear(Image img, float radio)
    {
        if (img != null) img.pixelsPerUnitMultiplier = BORDE_BASE / Mathf.Max(radio, 0.01f);
    }

    // ================= Sprites generados por código =================
    static float DistRedondeado(float x, float y, float mitad, float medioLado, float radio)
    {
        float qx = Mathf.Abs(x - mitad) - (medioLado - radio);
        float qy = Mathf.Abs(y - mitad) - (medioLado - radio);
        return new Vector2(Mathf.Max(qx, 0f), Mathf.Max(qy, 0f)).magnitude
               + Mathf.Min(Mathf.Max(qx, qy), 0f) - radio;
    }

    // filo = false: forma rellena | filo = true: línea fina con brillo diagonal
    static Sprite CrearForma(bool filo)
    {
        int tam = 256;
        float radio = 120f, suave = 1.5f, trazo = 2.5f;
        float mitad = tam / 2f, medioLado = mitad - suave, borde = radio + suave;
        var tex = NuevaTextura(tam, tam);
        var px = new Color32[tam * tam];
        Vector2 diagonal = new Vector2(-1f, 1f).normalized;
        for (int y = 0; y < tam; y++)
            for (int x = 0; x < tam; x++)
            {
                float d = DistRedondeado(x + 0.5f, y + 0.5f, mitad, medioLado, radio);
                float a = Mathf.Clamp01(0.5f - d / suave);
                if (filo)
                {
                    a *= Mathf.Clamp01(0.5f + (d + trazo) / suave);
                    Vector2 dir = new Vector2(x + 0.5f - mitad, y + 0.5f - mitad).normalized;
                    float luz = Mathf.Abs(Vector2.Dot(dir, diagonal)); // 1 en esquinas sup-izq / inf-der
                    a *= Mathf.Lerp(0.35f, 1f, luz * luz);
                }
                px[y * tam + x] = new Color32(255, 255, 255, (byte)(255f * a));
            }
        tex.SetPixels32(px);
        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, tam, tam), new Vector2(0.5f, 0.5f), 100f, 0,
                             SpriteMeshType.FullRect, new Vector4(borde, borde, borde, borde));
    }

    static Sprite SpriteBase() { if (spriteBase == null) spriteBase = CrearForma(false); return spriteBase; }
    static Sprite SpriteFilo() { if (spriteFilo == null) spriteFilo = CrearForma(true); return spriteFilo; }

    static Sprite SpriteSuave()
    {
        if (spriteSuave != null) return spriteSuave;
        int tam = 128;
        float radio = 28f, mitad = tam / 2f, medioLado = mitad - SUAVE;
        var tex = NuevaTextura(tam, tam);
        var px = new Color32[tam * tam];
        for (int y = 0; y < tam; y++)
            for (int x = 0; x < tam; x++)
            {
                float d = DistRedondeado(x + 0.5f, y + 0.5f, mitad, medioLado, radio);
                float t = Mathf.Clamp01((d + SUAVE) / (2f * SUAVE));
                t = t * t * (3f - 2f * t);
                px[y * tam + x] = new Color32(255, 255, 255, (byte)(255f * (1f - t)));
            }
        tex.SetPixels32(px);
        tex.Apply();
        float borde = radio + SUAVE;
        spriteSuave = Sprite.Create(tex, new Rect(0, 0, tam, tam), new Vector2(0.5f, 0.5f), 100f, 0,
                                    SpriteMeshType.FullRect, new Vector4(borde, borde, borde, borde));
        return spriteSuave;
    }

    // Esquina fina del recuadro en "L" con curva amplia
    static Sprite SpriteEsquina()
    {
        if (spriteEsquina != null) return spriteEsquina;
        int n = 192;
        float grosor = 10f, radio = 56f, medio = grosor / 2f;
        Vector2 centro = new Vector2(radio, radio);
        var tex = NuevaTextura(n, n);
        var px = new Color32[n * n];
        for (int y = 0; y < n; y++)
            for (int x = 0; x < n; x++)
            {
                Vector2 p = new Vector2(x + 0.5f, y + 0.5f);
                float d;
                if (p.x <= radio && p.y <= radio)
                    d = Mathf.Abs(Vector2.Distance(p, centro) - (radio - medio));
                else if (p.y > radio)
                    d = Vector2.Distance(p, new Vector2(medio, Mathf.Min(p.y, n - medio)));
                else
                    d = Vector2.Distance(p, new Vector2(Mathf.Min(p.x, n - medio), medio));
                px[y * n + x] = new Color32(255, 255, 255, (byte)(255f * Mathf.Clamp01((medio - d) / 1.2f + 0.5f)));
            }
        tex.SetPixels32(px);
        tex.Apply();
        spriteEsquina = Sprite.Create(tex, new Rect(0, 0, n, n), Vector2.zero, 100f);
        return spriteEsquina;
    }

    static Sprite SpriteDegradado()
    {
        if (spriteDegradado != null) return spriteDegradado;
        int alto = 64, ancho = 8;
        var tex = NuevaTextura(ancho, alto);
        var px = new Color32[ancho * alto];
        for (int y = 0; y < alto; y++)
        {
            byte a = (byte)(255f * Mathf.Pow(1f - y / (alto - 1f), 1.6f));
            for (int x = 0; x < ancho; x++) px[y * ancho + x] = new Color32(255, 255, 255, a);
        }
        tex.SetPixels32(px);
        tex.Apply();
        spriteDegradado = Sprite.Create(tex, new Rect(0, 0, ancho, alto), Vector2.zero, 100f);
        return spriteDegradado;
    }

    static Texture2D NuevaTextura(int w, int h)
    {
        var tex = new Texture2D(w, h, TextureFormat.RGBA32, true);
        tex.wrapMode = TextureWrapMode.Clamp;
        tex.filterMode = FilterMode.Trilinear;
        tex.anisoLevel = 4;
        tex.mipMapBias = -0.3f;
        return tex;
    }
}