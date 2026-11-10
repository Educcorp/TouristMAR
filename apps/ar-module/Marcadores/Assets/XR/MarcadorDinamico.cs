using System.Collections;
using UnityEngine;
using UnityEngine.Networking;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARSubsystems;
using TMPro;

[System.Serializable]
public class DatosMarcador {
    public string nombre;
    public string urlImagen;
    public string textoParaMostrar;
}

[System.Serializable]
public class ListaDesdeAdmin {
    public DatosMarcador[] marcadores;
}

public class MarcadorDinamico : MonoBehaviour
{
    public ARTrackedImageManager managerDeImagenes;
    public string urlDeTuApi = "https://touristmar-production.up.railway.app/api/marcadores";
    public TMP_Text textoInfo;   

    const string MENSAJE_CENTRAR = "Centra el marcador en el recuadro";

    private string nombreMarcadorActual = "";
    private bool sistemaListo = false;

    void Start()
    {
        urlDeTuApi = urlDeTuApi.Trim();

        if (textoInfo == null)
        {
            GameObject obj = GameObject.Find("TextoInfo");
            if (obj != null) textoInfo = obj.GetComponent<TMP_Text>();
        }
        if (textoInfo == null)
            Debug.LogError("MarcadorDinamico: no se encontró TextoInfo. Asígnalo en el Inspector.");

        CambiarTexto("Cargando sistema...");
        StartCoroutine(ProcesarCargaInicial());
    }

    IEnumerator ProcesarCargaInicial()
    {
        CambiarTexto("Conectando con la API...");

        var libreriaDinamica = managerDeImagenes.CreateRuntimeLibrary() as MutableRuntimeReferenceImageLibrary;
        if (libreriaDinamica == null)
        {
            Diagnostico("ERROR: La librería dinámica AR no es soportada.", true);
            CambiarTexto("Este dispositivo no soporta marcadores dinámicos.");
            yield break;
        }

        UnityWebRequest request = UnityWebRequest.Get(urlDeTuApi);
        yield return request.SendWebRequest();

        if (request.result != UnityWebRequest.Result.Success)
        {
            Diagnostico("ERROR API: " + request.error, true);
            CambiarTexto("Error de conexión con la API.");
            yield break;
        }

        ListaDesdeAdmin datos = ParsearJson(request.downloadHandler.text);
        if (datos == null || datos.marcadores == null || datos.marcadores.Length == 0)
        {
            Diagnostico("ERROR: JSON sin marcadores válidos.", true);
            CambiarTexto("No se encontraron marcadores.");
            yield break;
        }

        int exitosos = 0;
        foreach (var marcador in datos.marcadores)
        {
            string nombreLimpio = marcador.nombre.Trim();
            CambiarTexto("Preparando marcadores...");
            yield return StartCoroutine(DescargarYConvertirFoto(marcador.urlImagen.Trim(), nombreLimpio, libreriaDinamica,
                (exito) => { if (exito) exitosos++; }));
        }

        managerDeImagenes.referenceLibrary = libreriaDinamica;
        managerDeImagenes.enabled = false;
        managerDeImagenes.enabled = true;

        Diagnostico($"ARKit Activo ({exitosos} marcadores listos)");
        sistemaListo = true;
        CambiarTexto(MENSAJE_CENTRAR);
    }

    IEnumerator DescargarYConvertirFoto(string urlFoto, string nombre, MutableRuntimeReferenceImageLibrary libreria, System.Action<bool> alTerminar)
    {
        UnityWebRequest request = UnityWebRequestTexture.GetTexture(urlFoto);
        yield return request.SendWebRequest();

        if (request.result != UnityWebRequest.Result.Success)
        {
            Diagnostico($"Error foto '{nombre}': " + request.error, true);
            alTerminar?.Invoke(false);
            yield break;
        }

        Texture2D texturaWeb = DownloadHandlerTexture.GetContent(request);
        if (texturaWeb == null) { alTerminar?.Invoke(false); yield break; }

        Texture2D texturaLimpia = ConvertirATexturaRGBA32(texturaWeb);
        var trabajo = libreria.ScheduleAddImageWithValidationJob(texturaLimpia, nombre, 0.2f);
        yield return new WaitUntil(() => trabajo.jobHandle.IsCompleted);

        bool ok = trabajo.status == AddReferenceImageJobStatus.Success;
        if (ok) Diagnostico($"Marcador OK: '{nombre}'");
        else Diagnostico($"ERROR ARKit estado: {trabajo.status} en '{nombre}'", true);
        alTerminar?.Invoke(ok);
    }

    Texture2D ConvertirATexturaRGBA32(Texture2D origen)
    {
        RenderTexture rt = RenderTexture.GetTemporary(origen.width, origen.height, 0, RenderTextureFormat.Default, RenderTextureReadWrite.Linear);
        Graphics.Blit(origen, rt);
        RenderTexture anterior = RenderTexture.active;
        RenderTexture.active = rt;

        Texture2D resultado = new Texture2D(origen.width, origen.height, TextureFormat.RGBA32, false);
        resultado.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        resultado.Apply();

        RenderTexture.active = anterior;
        RenderTexture.ReleaseTemporary(rt);
        return resultado;
    }

    void Update()
    {
        if (!sistemaListo) return;

        ARTrackedImage marcadorVisto = null;
        foreach (var trackable in managerDeImagenes.trackables)
        {
            if (trackable.trackingState == TrackingState.Tracking)
            {
                marcadorVisto = trackable;
                break;
            }
        }

        if (marcadorVisto != null)
        {
            string nombreVisto = marcadorVisto.referenceImage.name.Trim();
            if (nombreMarcadorActual != nombreVisto)
            {
                nombreMarcadorActual = nombreVisto;
                Diagnostico($"Detectado: {nombreVisto}");
                CambiarTexto("Consultando información...");
                StartCoroutine(ConsultarInformacionEnVivo(nombreVisto));
            }
        }
        else if (nombreMarcadorActual != "")
        {
            nombreMarcadorActual = "";
            Diagnostico("Buscando...");
            CambiarTexto(MENSAJE_CENTRAR);
        }
    }

    IEnumerator ConsultarInformacionEnVivo(string nombreBuscado)
    {
        UnityWebRequest request = UnityWebRequest.Get(urlDeTuApi);
        yield return request.SendWebRequest();

        if (nombreMarcadorActual != nombreBuscado) yield break;

        if (request.result != UnityWebRequest.Result.Success)
        {
            Diagnostico("Error al consultar info: " + request.error, true);
            CambiarTexto("Error al obtener la información.");
            yield break;
        }

        ListaDesdeAdmin datos = ParsearJson(request.downloadHandler.text);
        if (datos?.marcadores != null)
        {
            foreach (var m in datos.marcadores)
            {
                if (m.nombre.Trim() == nombreBuscado)
                {
                    if (string.IsNullOrWhiteSpace(m.textoParaMostrar))
                        Diagnostico($"'{nombreBuscado}' no tiene textoParaMostrar en la API", true);

                    CambiarTexto(m.textoParaMostrar);
                    yield break;
                }
            }
        }
        CambiarTexto($"Sin datos para: {nombreBuscado}");
    }

    ListaDesdeAdmin ParsearJson(string texto)
    {
        texto = texto.Trim();
        if (texto.StartsWith("[")) texto = "{\"marcadores\":" + texto + "}";
        try { return JsonUtility.FromJson<ListaDesdeAdmin>(texto); }
        catch { return null; }
    }

    void CambiarTexto(string nuevo)
    {
        if (textoInfo != null) textoInfo.text = nuevo;
    }

    void Diagnostico(string mensaje, bool esError = false)
    {
        if (esError) Debug.LogWarning("[AR] " + mensaje);
        else Debug.Log("[AR] " + mensaje);
    }
}