#if UNITY_EDITOR
using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// Exporta el proyecto de Unity como librería de Android (unityLibrary) para
/// meterlo en el APK de Flutter (apps/mobile/android/settings.gradle.kts lo
/// busca en apps/ar-module/builds/android/ar-marcadores/unityLibrary).
///
/// Se corre sin abrir la ventana de Unity (lo hace scripts/exportar-unity.ps1):
///   Unity.exe -batchmode -quit -projectPath C:\ar\touristmar -buildTarget Android
///     -executeMethod ExportarLibreria.Exportar -salida C:\ar\salida\ar-marcadores
///
/// Ajustes que necesita la app (ver MainActivity.kt y notas del proyecto):
/// - Actividad de Unity: UnityPlayerGameActivity (Application Entry = GameActivity).
/// - OpenGLES3 (con Vulkan la cámara de ARCore sale negra).
/// - Android 10 (API 29) mínimo, IL2CPP, ARM64.
/// </summary>
public static class ExportarLibreria
{
    public static void Exportar()
    {
        var salida = Argumento("-salida")
            ?? Path.GetFullPath(Path.Combine(Application.dataPath, "..", "Builds", "ar-marcadores"));

        // Escenas: las de File → Build Profiles → Scene List (la primera es la que
        // abre la app). Si no hay ninguna marcada, todas las del proyecto menos
        // los ejemplos de TextMesh Pro.
        var escenas = EditorBuildSettings.scenes.Where(s => s.enabled).Select(s => s.path).ToArray();
        if (escenas.Length == 0)
        {
            escenas = AssetDatabase.FindAssets("t:Scene", new[] { "Assets" })
                .Select(AssetDatabase.GUIDToAssetPath)
                .Where(p => !p.Contains("TextMesh Pro") && !p.Contains("Samples"))
                .ToArray();
        }
        Debug.Log("[ExportarLibreria] Escenas:\n  " + string.Join("\n  ", escenas));
        if (escenas.Length == 0)
        {
            Debug.LogError("[ExportarLibreria] El proyecto no tiene escenas.");
            EditorApplication.Exit(1);
            return;
        }

        EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);
        EditorUserBuildSettings.exportAsGoogleAndroidProject = true;

        var android = NamedBuildTarget.Android;
        PlayerSettings.SetScriptingBackend(android, ScriptingImplementation.IL2CPP);
        PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
        PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel29;
        PlayerSettings.Android.applicationEntry = AndroidApplicationEntry.GameActivity;
        PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.Android, false);
        PlayerSettings.SetGraphicsAPIs(BuildTarget.Android, new[] { GraphicsDeviceType.OpenGLES3 });

        if (Directory.Exists(salida)) Directory.Delete(salida, true);
        Directory.CreateDirectory(salida);

        var reporte = BuildPipeline.BuildPlayer(new BuildPlayerOptions
        {
            scenes = escenas,
            locationPathName = salida,
            target = BuildTarget.Android,
            options = BuildOptions.None,
        });

        var resumen = reporte.summary;
        if (resumen.result != BuildResult.Succeeded)
        {
            Debug.LogError($"[ExportarLibreria] Falló: {resumen.result} ({resumen.totalErrors} errores).");
            EditorApplication.Exit(1);
            return;
        }
        Debug.Log($"[ExportarLibreria] Listo en {salida} ({resumen.totalSize / 1048576} MB).");
    }

    static string Argumento(string nombre)
    {
        var args = Environment.GetCommandLineArgs();
        var i = Array.IndexOf(args, nombre);
        return i >= 0 && i + 1 < args.Length ? args[i + 1] : null;
    }
}
#endif
