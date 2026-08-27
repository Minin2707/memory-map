import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePropertiesFile = rootProject.file("key.properties")
val releaseKeystoreProperties = Properties()

if (releaseKeystorePropertiesFile.exists()) {
    FileInputStream(releaseKeystorePropertiesFile).use {
        releaseKeystoreProperties.load(it)
    }
}

fun releaseKeystoreProperty(name: String): String? =
    releaseKeystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }

fun isReleaseSigningConfigured(): Boolean =
    releaseKeystorePropertiesFile.exists() &&
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            .all { releaseKeystoreProperty(it) != null }

android {
    namespace = "com.memorymap.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.1.13356709"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.memorymap.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"

    productFlavors {
        create("production") {
            dimension = "environment"
        }

        create("localPerformance") {
            dimension = "environment"
            applicationIdSuffix = ".localperformance"
            versionNameSuffix = "-local-performance"
        }
    }

    signingConfigs {
        create("release") {
            if (isReleaseSigningConfigured()) {
                storeFile = rootProject.file(releaseKeystoreProperty("storeFile")!!)
                storePassword = releaseKeystoreProperty("storePassword")
                keyAlias = releaseKeystoreProperty("keyAlias")
                keyPassword = releaseKeystoreProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (isReleaseSigningConfigured()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

gradle.taskGraph.whenReady {
    val productionReleaseRequested = allTasks.any { task ->
        val name = task.name.lowercase()
        name.contains("productionrelease") ||
            name == "assemblerelease" ||
            name == "bundlerelease"
    }

    if (productionReleaseRequested && !isReleaseSigningConfigured()) {
        throw GradleException(
            "Production release signing is not configured. " +
                "Create mobile/android/key.properties with storeFile, " +
                "storePassword, keyAlias, and keyPassword. Do not commit " +
                "key.properties or keystore files."
        )
    }
}
