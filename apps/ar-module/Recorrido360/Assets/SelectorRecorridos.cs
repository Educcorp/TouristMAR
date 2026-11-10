using UnityEngine;
using UnityEngine.Networking;
using System.Collections;
using System.Linq;

[System.Serializable]
public class Escena { public string titulo; public string urlImagen; }

[System.Serializable]
public class DatosRecorrido { public string nombre; public string textoParaMostrar; public string negocioId; public string urlPortada; public Escena[] escenas; }

[System.Serializable]
public class RespuestaRecorridos { public DatosRecorrido[] recorridos; }

public class SelectorRecorridos : MonoBehaviour
{
    [Header("Conexión")]
    public string urlApi = "https://touristmar-production.up.railway.app/api/recorridos";

    [Header("Interfaz y Visor")]
    public Material materialEsfera360; 
    public GameObject pantallaCarga; 

    private int indiceFotoActual = 0;
    private Texture2D[] texturasDescargadas; 

    void Start()
    {
        RenderSettings.fog = false;

        if (materialEsfera360 != null)
        {
            if (materialEsfera360.HasProperty("_Tint")) materialEsfera360.SetColor("_Tint", Color.white);
            if (materialEsfera360.HasProperty("_Exposure")) materialEsfera360.SetFloat("_Exposure", 1.0f);
        }

        // Simulación de prueba local
       // IniciarRecorridoDesdeApp("prueba2"); 
    }

    public void IniciarRecorridoDesdeApp(string idOTexto)
    {
        if (pantallaCarga != null) pantallaCarga.SetActive(true); 
        StartCoroutine(BuscarYDescargar(idOTexto));
    }

    IEnumerator BuscarYDescargar(string idBuscado)
    {
        using (UnityWebRequest uwr = UnityWebRequest.Get(urlApi))
        {
            yield return uwr.SendWebRequest();

            if (uwr.result == UnityWebRequest.Result.Success)
            {
                RespuestaRecorridos respuesta = JsonUtility.FromJson<RespuestaRecorridos>(uwr.downloadHandler.text);
                if (respuesta != null && respuesta.recorridos != null)
                {
                    DatosRecorrido recorrido = respuesta.recorridos.FirstOrDefault(r => r.negocioId == idBuscado || r.nombre == idBuscado);
                    if (recorrido != null) 
                    {
                        StartCoroutine(DescargarTodasLasFotos(recorrido));
                    }
                    else 
                    {
                        Debug.LogError("🔴 No se encontró el recorrido: " + idBuscado);
                        if (pantallaCarga != null) pantallaCarga.SetActive(false);
                    }
                }
            }
            else
            {
                Debug.LogError("🔴 Error de red API: " + uwr.error);
                if (pantallaCarga != null) pantallaCarga.SetActive(false);
            }
        }
    }

    IEnumerator DescargarTodasLasFotos(DatosRecorrido datos)
    {
        if (datos.escenas == null || datos.escenas.Length == 0)
        {
            if (pantallaCarga != null) pantallaCarga.SetActive(false);
            yield break;
        }

        indiceFotoActual = 0;
        texturasDescargadas = new Texture2D[datos.escenas.Length]; 

        for (int i = 0; i < datos.escenas.Length; i++)
        {
            using (UnityWebRequest uwr = UnityWebRequestTexture.GetTexture(datos.escenas[i].urlImagen))
            {
                yield return uwr.SendWebRequest();
                if (uwr.result == UnityWebRequest.Result.Success)
                {
                    Texture2D tex = DownloadHandlerTexture.GetContent(uwr);
                    tex.wrapMode = TextureWrapMode.Clamp;
                    tex.filterMode = FilterMode.Bilinear;
                    texturasDescargadas[i] = tex; 
                    Debug.Log($"🟢 Foto {i + 1} descargada correctamente.");
                }
                else
                {
                    Debug.LogError($"🔴 Falló la descarga de la Foto {i + 1}: {uwr.error}");
                }
            }
        }

        AplicarFoto(0); 
        
      
        if (pantallaCarga != null) pantallaCarga.SetActive(false); 
    }

    void AplicarFoto(int indice)
    {
        if (texturasDescargadas != null && indice >= 0 && indice < texturasDescargadas.Length)
        {
            if (texturasDescargadas[indice] != null)
            {
                materialEsfera360.mainTexture = texturasDescargadas[indice];
                RenderSettings.skybox = materialEsfera360;
                Debug.Log($"📸 Mostrando foto {indice + 1} de {texturasDescargadas.Length}");
            }
            else
            {
                Debug.LogWarning($"⚠️ La foto {indice + 1} no se cargó correctamente.");
            }
        }
    }

    public void IrSiguienteFoto()
    {
        Debug.Log("➡️ Botón Siguiente presionado");
        if (texturasDescargadas == null || texturasDescargadas.Length == 0) return;
        
        indiceFotoActual = (indiceFotoActual + 1) % texturasDescargadas.Length;
        AplicarFoto(indiceFotoActual);
    }

    public void IrFotoAnterior()
    {
        Debug.Log("⬅️ Botón Atrás presionado");
        if (texturasDescargadas == null || texturasDescargadas.Length == 0) return;
        
        indiceFotoActual--;
        if (indiceFotoActual < 0) indiceFotoActual = texturasDescargadas.Length - 1;
        AplicarFoto(indiceFotoActual);
    }
}