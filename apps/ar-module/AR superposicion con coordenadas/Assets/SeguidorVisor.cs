using UnityEngine;

public class SeguidorVisor : MonoBehaviour
{
    public Transform camara;
    public float distancia = 1.2f;       // Distancia frente a tus ojos (en metros)
    public float velocidadSuave = 4.0f;  // Qué tan rápido o suave se acomoda

    void Start()
    {
        // Si no asignaste la cámara, la busca automáticamente
        if (camara == null && Camera.main != null)
        {
            camara = Camera.main.transform;
        }
    }

    void Update()
    {
        if (camara == null) return;

        // 1. Calcula el punto flotante frente a donde miras
        Vector3 posicionObjetivo = camara.position + camara.forward * distancia;
        
        // 2. Se desplaza de forma fluida hacia ese punto
        transform.position = Vector3.Lerp(transform.position, posicionObjetivo, Time.deltaTime * velocidadSuave);

        // 3. Gira suavemente para quedar de frente a tus ojos
        Quaternion rotacionObjetivo = Quaternion.LookRotation(transform.position - camara.position);
        transform.rotation = Quaternion.Slerp(transform.rotation, rotacionObjetivo, Time.deltaTime * velocidadSuave);
    }
}