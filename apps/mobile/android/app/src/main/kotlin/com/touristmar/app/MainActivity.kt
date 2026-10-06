package com.touristmar.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Abre el módulo de Unity (RA con marcadores, recorrido 360° o RA por
 * coordenadas) como una pantalla aparte. Unity corre en su propio proceso
 * (":unity", ver AndroidManifest): al cerrarlo con X o "atrás" se vuelve a esta
 * actividad sin perder la sesión ni la pantalla de Flutter.
 *
 * Canal "touristmar/ar" — contraparte en lib/ar/unity_experiencias_launcher.dart.
 * Unity lee los extras "escena", "parametro" y "apiBaseUrl" (ar-module:
 * ParametrosApp.cs y Recorrido/VisorRecorrido360.cs).
 */
class MainActivity : FlutterActivity() {
    private var pendiente: Pendiente? = null

    private class Pendiente(val escena: String, val parametro: String, val apiBaseUrl: String, val result: MethodChannel.Result)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL).setMethodCallHandler { call, result ->
            when (call.method) {
                "disponible" -> result.success(unityIncluido())
                "abrir" -> abrir(
                    call.argument<String>("escena") ?: "marcadores",
                    call.argument<String>("parametro") ?: "",
                    call.argument<String>("apiBaseUrl") ?: "",
                    result,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun unityIncluido(): Boolean =
        try {
            Class.forName(UNITY_ACTIVITY)
            true
        } catch (_: ClassNotFoundException) {
            false
        }

    private fun permisosPara(escena: String): Array<String> = when (escena) {
        "recorrido" -> emptyArray()
        "geo" -> arrayOf(Manifest.permission.CAMERA, Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        else -> arrayOf(Manifest.permission.CAMERA)
    }

    private fun abrir(escena: String, parametro: String, apiBaseUrl: String, result: MethodChannel.Result) {
        if (!unityIncluido()) {
            result.error("no_disponible", "Esta versión de la app no incluye el módulo de realidad aumentada.", null)
            return
        }
        val faltan = permisosPara(escena).filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (faltan.isEmpty()) {
            lanzarUnity(escena, parametro, apiBaseUrl, result)
            return
        }
        pendiente?.result?.error("cancelado", "Se pidió abrir otra experiencia.", null)
        pendiente = Pendiente(escena, parametro, apiBaseUrl, result)
        requestPermissions(faltan.toTypedArray(), PERMISOS)
    }

    private fun lanzarUnity(escena: String, parametro: String, apiBaseUrl: String, result: MethodChannel.Result) {
        if (escena == "geo") {
            val gps = getSystemService(LOCATION_SERVICE) as LocationManager
            if (!gps.isProviderEnabled(LocationManager.GPS_PROVIDER) && !gps.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                result.error("gps_apagado", "Activa la ubicación (GPS) del teléfono para usar la realidad aumentada por ubicación.", null)
                return
            }
        }
        startActivity(
            Intent().setClassName(this, UNITY_ACTIVITY)
                .putExtra("escena", escena)
                .putExtra("parametro", parametro)
                .putExtra("apiBaseUrl", apiBaseUrl),
        )
        result.success(null)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISOS) return
        val p = pendiente ?: return
        pendiente = null
        val negados = permissions.filterIndexed { i, _ -> grantResults.getOrNull(i) != PackageManager.PERMISSION_GRANTED }
        when {
            Manifest.permission.CAMERA in negados ->
                p.result.error("sin_permiso", "Para ver la realidad aumentada necesitas permitir el uso de la cámara.", null)
            Manifest.permission.ACCESS_FINE_LOCATION in negados && Manifest.permission.ACCESS_COARSE_LOCATION in negados ->
                p.result.error("sin_permiso", "Para la realidad aumentada por ubicación necesitas permitir el acceso a tu ubicación.", null)
            else -> lanzarUnity(p.escena, p.parametro, p.apiBaseUrl, p.result)
        }
    }

    companion object {
        private const val CANAL = "touristmar/ar"
        private const val UNITY_ACTIVITY = "com.unity3d.player.UnityPlayerGameActivity"
        private const val PERMISOS = 4001
    }
}
