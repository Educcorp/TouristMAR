using TMPro;
using UnityEngine;

namespace TouristMAR.AR
{
    /// <summary>
    /// Va en la raíz del prefab que aparece flotando sobre cada marcador
    /// (Assets/Prefabs/InfoMarcador.prefab). Sirve tanto con TextMeshPro 3D como
    /// con TextMeshProUGUI dentro de un Canvas en World Space, porque ambos
    /// heredan de TMP_Text.
    /// </summary>
    public class InfoMarcadorUI : MonoBehaviour
    {
        [Tooltip("Donde se pinta textoParaMostrar (título + información en dos líneas).")]
        [SerializeField] private TMP_Text texto;

        [Tooltip("Separación sobre la imagen, en metros (eje Y local del marcador).")]
        [SerializeField] private float altura = 0.05f;
        [Tooltip("Gira la tarjeta hacia la cámara para que siempre se pueda leer.")]
        [SerializeField] private bool mirarCamara = true;

        private Transform camara;

        public void Mostrar(string textoParaMostrar)
        {
            if (texto != null) texto.text = textoParaMostrar;
            transform.localPosition = new Vector3(0f, altura, 0f);
        }

        public void SetVisible(bool visible)
        {
            if (gameObject.activeSelf != visible) gameObject.SetActive(visible);
        }

        private void LateUpdate()
        {
            if (!mirarCamara) return;
            if (camara == null)
            {
                if (Camera.main == null) return;
                camara = Camera.main.transform;
            }

            // Mismo sentido que la cámara (no "hacia" ella): así el texto no se
            // ve en espejo.
            transform.rotation = Quaternion.LookRotation(transform.position - camara.position, Vector3.up);
        }
    }
}
