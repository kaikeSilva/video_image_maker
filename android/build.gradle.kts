allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://repo.maven.apache.org/maven2") }
        maven { url = uri("https://www.jitpack.io") }
        maven { url = uri("https://maven.arthenica.com/repository/ffmpeg-kit") }
        gradlePluginPortal()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Força namespace e Java 17 para todas as dependências
subprojects {
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            with(extensions.findByName("android") as com.android.build.gradle.BaseExtension) {
                try {
                    // Tenta definir o namespace se não estiver definido
                    if (project.group != null && project.group.toString().isNotEmpty()) {
                        try {
                            val namespaceField = javaClass.getDeclaredMethod("getNamespace")
                            if (namespaceField != null) {
                                val currentNamespace = namespaceField.invoke(this) as? String
                                if (currentNamespace == null || currentNamespace.isEmpty()) {
                                    javaClass.getDeclaredMethod("setNamespace", String::class.java)
                                        .invoke(this, project.group.toString())
                                }
                            }
                        } catch (e: Exception) {
                            // Ignora erro se o método não existir
                        }
                    }
                    
                    // Define Java 17
                    compileOptions.apply {
                        sourceCompatibility = JavaVersion.VERSION_17
                        targetCompatibility = JavaVersion.VERSION_17
                    }
                } catch (e: Exception) {
                    // Ignora erros
                }
            }
            
            // Força Kotlin JVM target 17
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                kotlinOptions {
                    jvmTarget = "17"
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
