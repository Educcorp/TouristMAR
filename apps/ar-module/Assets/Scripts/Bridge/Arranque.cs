using UnityEngine;
using UnityEngine.SceneManagement;

namespace TouristMAR
{
    /// <summary>
    /// Escena "Arranque" (la PRIMERA en File → Build Profiles → Scene List):
    /// lee qué experiencia pidió la app (<see cref="ParametrosApp.Escena"/>) y
    /// carga su escena. Ponle este componente a un GameObject vacío y escribe en
    /// el Inspector el nombre exacto de cada escena de tu proyecto.
    /// El recorrido 360° no pasa por aquí: lo hace Flutter (visor_360.dart).
    /// </summary>
    public class Arranque : MonoBehaviour
    {
        [Tooltip("Escena de RA con marcadores (MarcadorDinamico + PuenteApp).")]
        [SerializeField] private string escenaMarcadores = "AR";
        [Tooltip("Escena de RA por geolocalización (CargadorLugarRA, GET /api/ra/lugares/{lugarId}).")]
        [SerializeField] private string escenaGeo = "Geo";

        private void Start()
        {
            var pedida = ParametrosApp.Escena;
            var destino = pedida switch
            {
                "geo" => escenaGeo,
                _ => escenaMarcadores,
            };
            Debug.Log($"[Arranque] escena='{pedida}' lugarId='{ParametrosApp.LugarId}' api='{ParametrosApp.ApiBaseUrl}' → {destino}");
            SceneManager.LoadScene(destino);
        }
    }
}
