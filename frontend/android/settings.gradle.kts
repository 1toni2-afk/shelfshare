pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Fixat sub 9.x: file_picker (11.0.2) își sare peste propriul plugin
    // Kotlin când detectează AGP 9+, presupunând că suportul "built-in
    // Kotlin" din AGP 9 va compila singur .kt-urile lui - la acest moment
    // asta nu se întâmplă corect, deci FilePickerPlugin.kt rămâne
    // necompilat ("cannot find symbol" în GeneratedPluginRegistrant.java).
    // Aceeași problemă afectează probabil mobile_scanner/share_plus (vezi
    // avertismentul de build despre plugin-uri ce aplică KGP).
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
