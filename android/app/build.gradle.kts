plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // ============================================================
    // === اسم الحزمة ===
    // ============================================================
    namespace = "com.lanphone.app"

    // ============================================================
    // === إصدارات SDK ===
    // ============================================================
    compileSdk = 34

    // إصدار NDK (مطلوب لـ flutter_webrtc)
    ndkVersion = "27.0.12077973"

    // ============================================================
    // === إصدارات Java و Kotlin ===
    // ============================================================
    compileOptions {
        // مطلوب لـ flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // ============================================================
    // === الإعدادات الافتراضية ===
    // ============================================================
    defaultConfig {
        applicationId = "com.lanphone.app"
        minSdk = 23
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // ============================================================
    // === أنواع البناء ===
    // ============================================================
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isDebuggable = true
        }
    }

    // ============================================================
    // === إعدادات الحزم ===
    // ============================================================
    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "META-INF/INDEX.LIST",
                "META-INF/*.kotlin_module"
            )
        }
    }

    // ============================================================
    // === Lint ===
    // ============================================================
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

// ============================================================
// === التبعيات ===
// ============================================================
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
