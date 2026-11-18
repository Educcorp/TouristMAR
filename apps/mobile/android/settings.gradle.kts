pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")

// Módulo de realidad aumentada (Unity as a Library). El export de Unity no se
// versiona (pesa cientos de MB y depende del SO donde se generó): se genera
// con apps/ar-module → ExportarLibreria y queda en builds/android/ar-marcadores.
// Sin él la app compila igual y la RA aparece como "no disponible".
// En Windows esa ruta puede pasar del límite de 260 caracteres: se puede
// poner otra más corta en android/unity.local.properties (no se sube a git;
// Flutter no lo toca, a diferencia de local.properties), p. ej.
//   touristmar.unityExport=C:/ar/salida/ar-marcadores
// (lo escribe scripts/exportar-unity.ps1).
val propsUnity = java.util.Properties().apply {
    for (nombre in listOf("local.properties", "unity.local.properties")) {
        file(nombre).takeIf { it.exists() }?.inputStream()?.use { load(it) }
    }
}
val unityExport = (propsUnity.getProperty("touristmar.unityExport")?.let { file(it) }
    ?: file("../../ar-module/builds/android/ar-marcadores")).resolve("unityLibrary")
// Solo si el export está completo (una copia a medias no debe romper el build).
if (unityExport.resolve("build.gradle").exists() &&
    unityExport.resolve("xrmanifest.androidlib/build.gradle").exists() &&
    unityExport.resolve("src/main/AndroidManifest.xml").exists()
) {
    include(":unityLibrary")
    project(":unityLibrary").projectDir = unityExport
    include(":unityLibrary:xrmanifest.androidlib")
    project(":unityLibrary:xrmanifest.androidlib").projectDir = unityExport.resolve("xrmanifest.androidlib")
}
