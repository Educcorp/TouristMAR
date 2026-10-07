using TMPro;
using UnityEngine;

namespace TouristMAR.Recorrido
{
    /// <summary>
    /// Flecha para pasar a otro escenario (componente raíz del prefab
    /// "FlechaRecorrido"). Mismo diseño que la flecha del visor de la app
    /// (_Flecha en apps/web/lib/widgets/recorrido360/visor_360.dart): círculo
    /// blanco con borde azul y flecha hacia arriba, y debajo una píldora negra
    /// semitransparente con el nombre del destino.
    ///
    /// El prefab necesita un Collider (p. ej. SphereCollider de radio ~0.35):
    /// <see cref="VisorRecorrido360"/> detecta el toque con un Raycast.
    /// </summary>
    public class FlechaRecorrido360 : MonoBehaviour
    {
        [SerializeField] private TMP_Text etiqueta;
        [Tooltip("La píldora de la etiqueta: se oculta si no hay texto.")]
        [SerializeField] private GameObject fondoEtiqueta;

        private Transform camara;

        /// <summary>Id del escenario al que lleva (DatosEnlace360.destino).</summary>
        public string Destino { get; private set; }

        public void Configurar(string destino, string texto, Camera camaraVisor)
        {
            Destino = destino;
            camara = camaraVisor.transform;
            if (etiqueta != null) etiqueta.text = texto;
            if (fondoEtiqueta != null) fondoEtiqueta.SetActive(!string.IsNullOrEmpty(texto));
        }

        private void LateUpdate()
        {
            // Siempre de frente a la cámara (billboard), como en la app.
            if (camara != null) transform.rotation = Quaternion.LookRotation(transform.position - camara.position, Vector3.up);
        }
    }
}
