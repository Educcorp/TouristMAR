using UnityEngine;

namespace TouristMAR
{
    /// <summary>
    /// Lo que la app (Flutter, MainActivity.kt) le manda a Unity al abrirlo, en
    /// los extras del Intent:
    /// <list type="bullet">
    /// <item><c>escena</c>: "marcadores" | "recorrido" | "geo" (ver <see cref="Arranque"/>).</item>
    /// <item><c>parametro</c>: en "recorrido", el nombre del recorrido; en "geo", el id del lugar.</item>
    /// <item><c>apiBaseUrl</c>: la API, con /api incluido (ej. https://touristmar-production.up.railway.app/api).</item>
    /// <item><c>lugarId</c>: el id del lugar desde el que se abrió. Es el MISMO id que usa
    /// Flutter: GET {apiBaseUrl}/ra/lugares/{lugarId} y GET {apiBaseUrl}/marcadores?negocioId={lugarId}.
    /// Vacío si se abrió sin un lugar.</item>
    /// </list>
    /// En el Editor (o un build suelto) no hay Intent: se usan los valores
    /// <c>PorDefecto</c>, que se pueden cambiar desde un script de prueba.
    /// </summary>
    public static class ParametrosApp
    {
        /// <summary>Solo Editor / build suelto. La API corre en el 5173 junto con el sitio.</summary>
        public static string ApiBaseUrlPorDefecto = "http://localhost:5173/api";
        /// <summary>Solo Editor / build suelto. FIME, el lugar de prueba.</summary>
        public static string LugarIdPorDefecto = "f24442e4-6613-4427-99df-a7f962d6b99e";
        public static string EscenaPorDefecto = "marcadores";
        public static string ParametroPorDefecto = "";

        public static string Escena => Extra("escena") ?? EscenaPorDefecto;
        public static string Parametro => Extra("parametro") ?? ParametroPorDefecto;
        public static string ApiBaseUrl => (Extra("apiBaseUrl") ?? ApiBaseUrlPorDefecto).TrimEnd('/');
        public static string LugarId => Extra("lugarId") ?? LugarIdPorDefecto;

        /// <summary>Un extra del Intent, o null si no viene (o en el Editor).</summary>
        public static string Extra(string clave)
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            try
            {
                using var unity = new AndroidJavaClass("com.unity3d.player.UnityPlayer");
                using var actividad = unity.GetStatic<AndroidJavaObject>("currentActivity");
                using var intent = actividad.Call<AndroidJavaObject>("getIntent");
                var valor = intent.Call<string>("getStringExtra", clave);
                return string.IsNullOrEmpty(valor) ? null : valor;
            }
            catch (System.Exception e)
            {
                Debug.LogWarning($"[ParametrosApp] No se pudo leer '{clave}': {e.Message}");
                return null;
            }
#else
            return null;
#endif
        }
    }
}
