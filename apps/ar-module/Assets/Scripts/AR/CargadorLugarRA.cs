using System;
using System.Collections;
using UnityEngine;
using UnityEngine.Networking;

namespace TouristMAR.AR
{
    /// <summary>
    /// Pide un lugar de la RA por geolocalización: GET {apiBaseUrl}/ra/lugares/{lugarId}
    /// (el mismo endpoint y el mismo id que usa Flutter). Nunca deja <c>puntos</c>
    /// en null: si la respuesta viene en el formato anterior (sin <c>puntos</c>, con
    /// <c>radioMetros</c>), arma un punto único con el pin del lugar.
    ///
    /// Uso:
    /// <code>
    /// StartCoroutine(CargadorLugarRA.Cargar(ParametrosApp.ApiBaseUrl, ParametrosApp.LugarId,
    ///     lugar => { foreach (var p in lugar.puntos) { ... } },
    ///     error => Debug.LogWarning(error)));
    /// </code>
    /// </summary>
    public static class CargadorLugarRA
    {
        /// <summary>Mismos valores por defecto que el backend y la app (metros).</summary>
        public const float RadioVisibleDefault = 100f;
        public const float RadioCercanoDefault = 10f;

        public static IEnumerator Cargar(string apiBaseUrl, string lugarId, Action<DatosLugarRA> alTerminar, Action<string> alFallar)
        {
            if (string.IsNullOrEmpty(lugarId))
            {
                alFallar?.Invoke("No se indicó el lugar (lugarId vacío).");
                yield break;
            }
            var url = $"{apiBaseUrl.TrimEnd('/')}/ra/lugares/{UnityWebRequest.EscapeURL(lugarId)}";
            using var req = UnityWebRequest.Get(url);
            yield return req.SendWebRequest();

            if (req.result != UnityWebRequest.Result.Success)
            {
                alFallar?.Invoke(req.responseCode == 404
                    ? "Ese lugar no existe o todavía no tiene ubicación."
                    : $"No se pudo conectar con {url}: {req.error}");
                yield break;
            }

            DatosLugarRA lugar;
            try
            {
                lugar = JsonUtility.FromJson<RespuestaLugarRA>(req.downloadHandler.text)?.lugar;
            }
            catch (Exception e)
            {
                alFallar?.Invoke($"La respuesta no es el JSON esperado: {e.Message}");
                yield break;
            }
            if (lugar == null || string.IsNullOrEmpty(lugar.id))
            {
                alFallar?.Invoke("La respuesta no trae 'lugar'.");
                yield break;
            }

            if (lugar.puntos == null || lugar.puntos.Length == 0)
            {
                // Formato anterior del contrato: el pin del lugar como punto único.
                var visible = lugar.radioMetros > 0 ? lugar.radioMetros : RadioVisibleDefault;
                lugar.puntos = new[]
                {
                    new DatosPuntoRA
                    {
                        id = lugar.id,
                        titulo = lugar.nombre,
                        resumen = "",
                        detalle = "",
                        urlImagen = lugar.urlPortada,
                        urlAudio = "",
                        latitud = lugar.latitud,
                        longitud = lugar.longitud,
                        radioVisible = visible,
                        radioCercano = Mathf.Min(RadioCercanoDefault, visible - 1f),
                    },
                };
            }
            alTerminar?.Invoke(lugar);
        }
    }
}
