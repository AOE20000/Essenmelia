allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// 移除先前为兼容 SDK 35 强制锁定的依赖版本，允许使用 SDK 36 要求的最新版
subprojects {
    // project.evaluationDependsOn(":app") // 移除这行，因为它可能导致过早评估
    
    project.afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library") || project.plugins.hasPlugin("com.android.application")) {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            android?.apply {
                // 仅在插件未定义 namespace 时进行注入，避免与新版插件冲突
                if (namespace == null) {
                    if (project.name == "quick_settings") {
                        namespace = "io.apparence.quick_settings"
                    } else if (project.name == "device_calendar") {
                        namespace = "com.builttoroam.devicecalendar"
                    } else {
                        namespace = "com.example.plugin.${project.name.replace("-", "_")}"
                    }
                }
                
                // 统一使用 SDK 36
                compileSdkVersion(36)
                
                defaultConfig {
                    minSdkVersion(24)
                    targetSdkVersion(36)
                }
            }
            
            project.tasks.withType<JavaCompile> {
                options.encoding = "UTF-8"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
