import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional release signing — create android/key.properties before Play upload:
//   storePassword=...
//   keyPassword=...
//   keyAlias=...
//   storeFile=/path/to/upload-keystore.jks
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val admobPropertiesFile = rootProject.file("admob.properties")
val admobProperties = Properties()
var admobAppId = "ca-app-pub-6928374150263841~1847293056"
if (admobPropertiesFile.exists()) {
    admobProperties.load(FileInputStream(admobPropertiesFile))
    admobAppId = admobProperties.getProperty("admob.app.id", admobAppId)
}

android {
    namespace = "com.devshujon.ds_video_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file("../${keystoreProperties["storeFile"] as String}")
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.devshujon.ds_video_player"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    buildTypes {
        debug {
            manifestPlaceholders["admobAppId"] =
                "ca-app-pub-3940256099942544~3347511713"
        }
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
