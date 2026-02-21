import java.util.Properties
import java.io.FileInputStream

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "org.essenmelia"
    // 升级到 SDK 36，用户已修复本地环境
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "org.essenmelia"
        // Flutter 3.38.9 (Preview) 建议 minSdk 至少为 24
        minSdk = 24
        targetSdk = 36
        versionCode = 30001
        versionName = "3.0.0"
        
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    val isRelease = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }

    splits {
        abi {
            isEnable = isRelease
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = isRelease
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // 禁用混淆和资源压缩以确保扩展兼容性
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(kotlin("stdlib"))
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.mlkit:text-recognition-chinese:16.0.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
}
