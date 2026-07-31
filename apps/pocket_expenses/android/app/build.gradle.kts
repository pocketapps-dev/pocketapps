import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties for local signing
fun loadKeyProperties(): Properties? {
    val keyPropertiesFile = File(flutterProjectRoot, "key.properties")
    if (keyPropertiesFile.exists()) {
        val properties = Properties()
        properties.load(FileInputStream(keyPropertiesFile))
        return properties
    }
    return null
}

val flutterProjectRoot = rootProject.projectDir.parentFile
val keyProperties = loadKeyProperties()

android {
    namespace = "pt.pocketapps.pocket_expenses"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "pt.pocketapps.pocket_expenses"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Priority: env vars > key.properties > default
            val storeFilePath = System.getenv("STORE_FILE")
                ?: keyProperties?.getProperty("storeFile")
            val storePasswordValue = System.getenv("STORE_PASSWORD")
                ?: keyProperties?.getProperty("storePassword")
            val keyAliasValue = System.getenv("KEY_ALIAS")
                ?: keyProperties?.getProperty("keyAlias")
            val keyPasswordValue = System.getenv("KEY_PASSWORD")
                ?: keyProperties?.getProperty("keyPassword")

            if (storeFilePath != null && storePasswordValue != null && keyAliasValue != null && keyPasswordValue != null) {
                storeFile = File(flutterProjectRoot, storeFilePath)
                storePassword = storePasswordValue
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
