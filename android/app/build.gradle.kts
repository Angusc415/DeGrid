import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun isReleaseTaskRequested(): Boolean {
    return gradle.startParameter.taskNames.any { taskName ->
        taskName.contains("release", ignoreCase = true)
    }
}

fun validateReleaseSigning() {
    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            "Missing android/key.properties for release builds. " +
                "Copy android/key.properties.template and configure your upload keystore.",
        )
    }

    val requiredKeys = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
    val missingKeys =
        requiredKeys.filter { key ->
            (keystoreProperties[key] as? String).isNullOrBlank()
        }

    if (missingKeys.isNotEmpty()) {
        throw GradleException(
            "android/key.properties is missing required entries: ${missingKeys.joinToString(", ")}",
        )
    }

    val storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
    if (!storeFile.exists()) {
        throw GradleException("Release keystore file not found: ${storeFile.path}")
    }
}

if (isReleaseTaskRequested()) {
    validateReleaseSigning()
}

android {
    namespace = "dev.degrid.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Must stay stable after the first Play upload (changing ID publishes a new app).
        applicationId = "dev.degrid.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
