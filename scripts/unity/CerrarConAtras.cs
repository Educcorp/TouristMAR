using UnityEngine;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

namespace TouristMAR
{
    /// <summary>
    /// Botón "atrás" de Android → cierra la RA y vuelve a la app de Flutter.
    /// Unity corre en su propio proceso (":unity", ver AndroidManifest de la
    /// app), así que Application.Quit solo cierra la RA, no la app.
    /// Se crea solo al arrancar cualquier escena: no hay que ponerlo en ninguna.
    /// </summary>
    public class CerrarConAtras : MonoBehaviour
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void Crear()
        {
            if (FindAnyObjectByType<CerrarConAtras>() != null) return;
            var go = new GameObject(nameof(CerrarConAtras));
            DontDestroyOnLoad(go);
            go.AddComponent<CerrarConAtras>();
        }

        private void Update()
        {
            var atras = false;
#if ENABLE_INPUT_SYSTEM
            // En Android, el botón/gesto "atrás" llega como la tecla Escape.
            atras |= Keyboard.current != null && Keyboard.current.escapeKey.wasPressedThisFrame;
#endif
#if ENABLE_LEGACY_INPUT_MANAGER
            atras |= Input.GetKeyDown(KeyCode.Escape);
#endif
            if (atras) Application.Quit();
        }
    }
}
