allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 移除先前为兼容 SDK 35 强制锁定的依赖版本，允许使用 SDK 36 要求的最新版
subprojects {
    project.afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library") || project.plugins.hasPlugin("com.android.application")) {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            android?.apply {
                if (namespace == null) {
                    namespace = "com.example.plugin.${project.name.replace("-", "_")}"
                }
                
                // 解决 AGP 8.x 对旧版插件 Manifest package 属性的限制
                // 通过动态注入 namespace 来覆盖旧版 package 声明
                if (project.name == "quick_settings") {
                    namespace = "io.apparence.quick_settings"
                }
                
                // 统一使用 SDK 36
                compileSdkVersion(36)
                
                defaultConfig {
                    minSdkVersion(24)
                    targetSdkVersion(36)
                    versionCode = 1
                    versionName = "1.0.0"
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
