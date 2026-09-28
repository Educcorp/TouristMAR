allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Plugins como file_picker (que usa la web) traen un compileSdk viejo fijo y sus
// dependencias piden 36+; se compilan todos con el mismo SDK que la app.
subprojects {
    afterEvaluate {
        if (project.name != "app") {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.compileSdkVersion(36)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
