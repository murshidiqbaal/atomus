plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.atomus.parentapp"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        getByName("debug") {
            isV1SigningEnabled = true
            isV2SigningEnabled = true
        }
        create("releaseConfig") {
            val debugConfig = getByName("debug")
            keyAlias = debugConfig.keyAlias
            keyPassword = debugConfig.keyPassword
            storeFile = debugConfig.storeFile
            storePassword = debugConfig.storePassword
            isV1SigningEnabled = true
            isV2SigningEnabled = true
        }
    }

    defaultConfig {
        applicationId = "com.atomus.parentapp"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("releaseConfig")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}
