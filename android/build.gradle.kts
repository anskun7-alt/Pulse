import org.gradle.kotlin.dsl.closureOf

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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    val manifestFile = file("src/main/AndroidManifest.xml")
    if (manifestFile.exists()) {
        var content = manifestFile.readText()
        if (content.contains("package=")) {
            content = content.replace(Regex("package=\"[^\"]*\""), "")
            manifestFile.writeText(content)
        }
    }

    pluginManager.withPlugin("com.android.application") {
        val androidExtension = extensions.getByType<com.android.build.gradle.BaseExtension>()
        if (androidExtension.namespace == null) {
            androidExtension.namespace = "com.pulse.player.${project.name.replace(":", ".").replace("-", ".") }"
        }
    }
    pluginManager.withPlugin("com.android.library") {
        val androidExtension = extensions.getByType<com.android.build.gradle.BaseExtension>()
        if (androidExtension.namespace == null) {
            androidExtension.namespace = "com.pulse.player.${project.name.replace(":", ".").replace("-", ".") }"
        }
    }

    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }
    
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

