using UnityEngine;
using UnityEngine.SceneManagement;

namespace TouristMAR
{
    /// <summary>
    /// Escena "Arranque" (la PRIMERA en File → Build Profiles → Scene List):
    /// lee qué experiencia pidió la app (<see cref="ParametrosApp.Escena"/>) y
    /// carga su escena. Ponle este componente a un GameObject vacío y escribe en
    /// el Inspector el nombre exacto de cada escena de tu proyecto.
    /// </summary>
    public class Arranque : MonoBehaviour
    {
        [Tooltip("Escena de RA con marcadores (MarcadorDinamico + PuenteApp).")]
        [SerializeField] private string escenaMarcadores = "AR";
        [Tooltip("Escena del visor de recorridos 360° (VisorRecorrido360).")]
        [SerializeField] private string escenaRecorrido = "Recorrido";
        [Tooltip("Escena de RA por geolocalización (solo si la app se compila con RA_GEO_EN_UNITY=true; por defecto la hace Flutter).")]
        [SerializeField] private string escenaGeo = "Geo";

        private void Start()
        {
            var pedida = ParametrosApp.Escena;
            var destino = pedida switch
            {
                "recorrido" => escenaRecorrido,
                "geo" => escenaGeo,
                _ => escenaMarcadores,
            };
            Debug.Log($"[Arranque] escena='{pedida}' lugarId='{ParametrosApp.LugarId}' api='{ParametrosApp.ApiBaseUrl}' → {destino}");
            SceneManager.LoadScene(destino);
        }
    }
}
