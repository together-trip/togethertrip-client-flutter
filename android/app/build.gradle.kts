import java.util.Base64
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.togethertrip.togethertrip"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.togethertrip.togethertrip"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // --dart-define=KAKAO_NATIVE_APP_KEY=xxx 값을 Android Manifest에 주입
        val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as? String)
            ?.split(",")
            ?.filter { it.isNotBlank() }
            ?.mapNotNull { encoded ->
                val decoded = String(Base64.getDecoder().decode(encoded))
                val idx = decoded.indexOf('=')
                if (idx <= 0) null else decoded.substring(0, idx) to decoded.substring(idx + 1)
            }
            ?.toMap()
            ?: emptyMap()
        manifestPlaceholders["kakaoNativeAppKey"] =
            dartDefines["KAKAO_NATIVE_APP_KEY"] ?: System.getenv("KAKAO_NATIVE_APP_KEY") ?: ""
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
