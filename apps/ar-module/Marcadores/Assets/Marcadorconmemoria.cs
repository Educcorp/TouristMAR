using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARSubsystems;

// Solo vigila si la cámara ve el marcador y lleva la cuenta de los 10 s.
// La información la sigue poniendo TU script (el que consulta la API);
// el visor la guarda y la protege mientras dura la cuenta.
public class MarcadorConMemoria : MonoBehaviour
{
    [Header("Referencias")]
    public ARTrackedImageManager manager;   // está en XR Origin
    public VisorARResponsive visor;         // está en CanvasVisor

    [Header("Memoria")]
    public float segundosDeMemoria = 10f;

    [Header("Texto cuando no hay marcador")]
    public string tituloInicial = "Escanea el marcador";
    [TextArea] public string infoInicial = "Centra el marcador en el recuadro";

    TrackableId actualId = TrackableId.invalidId;
    bool loVeo;
    float tiempoRestante;

    void OnEnable()  { if (manager != null) manager.trackablesChanged.AddListener(AlCambiar); }
    void OnDisable() { if (manager != null) manager.trackablesChanged.RemoveListener(AlCambiar); }

    void Start() { VolverAlInicio(); }

    void AlCambiar(ARTrackablesChangedEventArgs<ARTrackedImage> e)
    {
        foreach (var img in e.added) Revisar(img);
        foreach (var img in e.updated) Revisar(img);
        foreach (var par in e.removed)
            if (par.Key == actualId && loVeo) EmpezarCuenta();
    }

    void Revisar(ARTrackedImage img)
    {
        if (img.trackingState == TrackingState.Tracking)
        {
            if (img.trackableId != actualId || !loVeo)
            {
                actualId = img.trackableId;
                loVeo = true;
                visor.SetDetectado(true);
                visor.SetProgreso(-1f);
            }
        }
        else if (img.trackableId == actualId && loVeo)
        {
            EmpezarCuenta();
        }
    }

    void EmpezarCuenta()
    {
        loVeo = false;
        tiempoRestante = segundosDeMemoria;
        visor.SetDetectado(false);
        visor.SetProgreso(1f, tiempoRestante);
    }

    void Update()
    {
        if (loVeo || actualId == TrackableId.invalidId) return;

        tiempoRestante -= Time.deltaTime;
        visor.SetProgreso(Mathf.Max(0f, tiempoRestante / segundosDeMemoria), Mathf.Max(0f, tiempoRestante));

        if (tiempoRestante <= 0f) VolverAlInicio();
    }

    void VolverAlInicio()
    {
        actualId = TrackableId.invalidId;
        loVeo = false;
        visor.SetDetectado(false);
        visor.SetProgreso(-1f);
        visor.SetTextos(tituloInicial, infoInicial);
    }
}