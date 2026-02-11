allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 强制统一依赖版本，防止出现要求 SDK 36 的库
subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.activity:activity:1.9.3")
            force("androidx.activity:activity-ktx:1.9.3")
            force("androidx.core:core:1.15.0")
            force("androidx.core:core-ktx:1.15.0")
            force("androidx.fragment:fragment:1.8.5")
            force("androidx.fragment:fragment-ktx:1.8.5")
            force("androidx.lifecycle:lifecycle-common:2.8.7")
            force("androidx.lifecycle:lifecycle-runtime:2.8.7")
            force("androidx.lifecycle:lifecycle-viewmodel:2.8.7")
            force("androidx.browser:browser:1.8.0")
        }
    }
}

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
                
                // 统一使用 SDK 35，因为本地 36 的 android.jar 缺失
                compileSdkVersion(35)
                
                defaultConfig {
                    minSdkVersion(24)
                    targetSdkVersion(35)
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
