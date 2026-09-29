import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Llave del proyecto (su SHA-1 está registrado en Google Cloud para el login
// con Google). android/key.properties y el .jks NO van al repo: se pasan por
// fuera. Sin key.properties se firma con la llave debug de la PC.
val firma = rootProject.file("key.properties")
val firmaProps = Properties().apply { if (firma.exists()) firma.inputStream().use { load(it) } }

android {
    namespace = "com.touristmar.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.touristmar.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // El módulo de RA de Unity requiere Android 10 (API 29).
        minSdk = if (findProject(":unityLibrary") != null) 29 else flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (firma.exists()) {
            create("release") {
                storeFile = file(firmaProps.getProperty("storeFile"))
                storePassword = firmaProps.getProperty("storePassword")
                keyAlias = firmaProps.getProperty("keyAlias")
                keyPassword = firmaProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            // Sin R8: borra clases que ARCore/Unity llaman desde código nativo
            // (p. ej. com.google.ar.core.SessionCreateJniHelper) y la cámara
            // de RA se queda en negro. Unity también compila sin minify.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// RA con marcadores: solo si existe el export de Unity (ver settings.gradle.kts).
if (findProject(":unityLibrary") != null) {
    dependencies {
        implementation(project(":unityLibrary"))
    }
}
