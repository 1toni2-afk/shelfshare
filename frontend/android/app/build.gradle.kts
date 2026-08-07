import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Push notifications (Firebase Cloud Messaging): pluginul google-services
// generează resursele native din google-services.json la build time și
// eșuează dacă fișierul lipsește. Fișierul e un secret de proiect (descărcat
// din consola Firebase, cu package name ro.shelfshare.shelfshare) și nu e
// commis în git - aplicăm pluginul doar dacă cineva l-a pus local, altfel
// buildul continuă normal, fără push notifications.
if (rootProject.file("app/google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Cheia de release (upload-keystore.jks / key.properties) e generată local și
// exclusă din git (vezi .gitignore) - fără ea, un build de release ar semna
// cu cheia de debug, pe care Google Play nu o acceptă pentru publicare.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "ro.shelfshare.shelfshare"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Cerut de flutter_local_notifications (folosește API-uri Java 8+ pe
        // care Android le suportă doar prin desugaring pe minSdk-uri vechi).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ro.shelfshare.shelfshare"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
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
            // Cade înapoi pe cheia de debug dacă key.properties lipsește (ex. pe
            // o mașină nouă, fără keystore-ul de release generat) - altfel
            // `flutter build` ar eșua direct în loc să producă un build de test.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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

dependencies {
    // Vezi compileOptions.isCoreLibraryDesugaringEnabled mai sus.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
