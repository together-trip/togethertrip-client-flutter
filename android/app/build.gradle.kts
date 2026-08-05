import java.util.Base64
import java.util.Properties
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

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use(keyProperties::load)
}

fun signingValue(propertyName: String, environmentName: String): String? =
    keyProperties.getProperty(propertyName)?.trim()?.takeIf(String::isNotEmpty)
        ?: System.getenv(environmentName)?.trim()?.takeIf(String::isNotEmpty)

val releaseSigningValues = mapOf(
    "storeFile" to signingValue("storeFile", "ANDROID_UPLOAD_STORE_FILE"),
    "storePassword" to signingValue("storePassword", "ANDROID_UPLOAD_STORE_PASSWORD"),
    "keyAlias" to signingValue("keyAlias", "ANDROID_UPLOAD_KEY_ALIAS"),
    "keyPassword" to signingValue("keyPassword", "ANDROID_UPLOAD_KEY_PASSWORD"),
)
val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true) &&
        listOf("assemble", "bundle", "package").any {
            taskName.contains(it, ignoreCase = true)
        }
}

if (releaseTaskRequested) {
    val missingSigningValues = releaseSigningValues
        .filterValues { it.isNullOrBlank() }
        .keys
    if (missingSigningValues.isNotEmpty()) {
        throw GradleException(
            "Android release signing 값이 없습니다: ${missingSigningValues.joinToString()}. " +
                "android/key.properties 또는 ANDROID_UPLOAD_* 환경 변수를 설정하세요.",
        )
    }

    val uploadStoreFile = rootProject.file(releaseSigningValues.getValue("storeFile")!!)
    if (!uploadStoreFile.isFile) {
        throw GradleException(
            "Android upload keystore를 찾을 수 없습니다: ${uploadStoreFile.absolutePath}",
        )
    }
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
        manifestPlaceholders["googleMapsApiKey"] =
            dartDefines["GOOGLE_MAPS_API_KEY"] ?: System.getenv("GOOGLE_MAPS_API_KEY") ?: ""

        if (releaseTaskRequested) {
            val requiredDartDefines = listOf(
                "API_BASE_URL",
                "SUPPORT_EMAIL",
                "KAKAO_NATIVE_APP_KEY",
                "GOOGLE_MAPS_API_KEY",
            )
            val missingDartDefines = requiredDartDefines.filter { name ->
                dartDefines[name].isNullOrBlank() && System.getenv(name).isNullOrBlank()
            }
            if (missingDartDefines.isNotEmpty()) {
                throw GradleException(
                    "Android release 필수 운영 값이 없습니다: ${missingDartDefines.joinToString()}. " +
                        "--dart-define-from-file 또는 환경 변수를 설정하세요.",
                )
            }

            val apiBaseUrl = dartDefines["API_BASE_URL"] ?: System.getenv("API_BASE_URL")!!
            if (!apiBaseUrl.startsWith("https://")) {
                throw GradleException("Android release API_BASE_URL은 HTTPS여야 합니다.")
            }
        }
    }

    signingConfigs {
        create("release") {
            if (releaseSigningValues.values.none { it.isNullOrBlank() }) {
                storeFile = rootProject.file(releaseSigningValues.getValue("storeFile")!!)
                storePassword = releaseSigningValues.getValue("storePassword")
                keyAlias = releaseSigningValues.getValue("keyAlias")
                keyPassword = releaseSigningValues.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
