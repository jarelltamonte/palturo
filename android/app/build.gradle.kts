import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
var keystoreLoadError: String? = null
if (keystorePropertiesFile.exists()) {
    try {
        FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
    } catch (error: Exception) {
        keystoreLoadError = error.message ?: error.toString()
    }
}

android {
    namespace = "app.palturo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "app.palturo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists() && keystoreLoadError == null) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                keystoreProperties.getProperty("storeFile")
                    ?.takeIf { it.isNotBlank() }
                    ?.let { storeFile = file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// Fail release packaging if the release keystore is absent or incomplete.
// Debug builds remain usable even when key.properties exists but points at a
// keystore that is not present yet.
gradle.taskGraph.whenReady {
    val releaseBuild = allTasks.any { task ->
        val name = task.name
        name.contains("Release", ignoreCase = true) &&
            (name.startsWith("assemble") ||
                name.startsWith("bundle") ||
                name.startsWith("package"))
    }
    if (releaseBuild) {
        if (!keystorePropertiesFile.exists()) {
            throw GradleException(
                "Release signing is not configured. Create android/key.properties " +
                    "from key.properties.example and point storeFile at a release " +
                    "keystore. Never commit the keystore or passwords.",
            )
        }
        if (keystoreLoadError != null) {
            throw GradleException(
                "Could not read android/key.properties: $keystoreLoadError. " +
                    "Use simple key=value lines and remove surrounding quotes.",
            )
        }
        val required = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
        val missing = required.filter {
            keystoreProperties.getProperty(it).isNullOrBlank()
        }
        if (missing.isNotEmpty()) {
            throw GradleException(
                "android/key.properties is missing: ${missing.joinToString(", ")}. " +
                    "Copy key.properties.example and fill every value.",
            )
        }
        val storePath = keystoreProperties.getProperty("storeFile")
        if (storePath == null || !file(storePath).exists()) {
            throw GradleException(
                "Release keystore not found at ${storePath ?: "<unset>"}. " +
                    "Set storeFile in android/key.properties.",
            )
        }
        if (
            keystoreProperties.getProperty("storePassword") == "REPLACE_WITH_SECRET" ||
            keystoreProperties.getProperty("keyPassword") == "REPLACE_WITH_SECRET"
        ) {
            throw GradleException(
                "android/key.properties still contains the example placeholder " +
                    "passwords. Replace them with the real values.",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
