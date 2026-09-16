plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // ============================================================
    // === اسم الحزمة (Package) ===
    // ============================================================
    namespace = "com.lanphone.app"

    // ============================================================
    // === إصدارات SDK ===
    // ============================================================
    // إصدار SDK المستخدم للبناء
    compileSdk = 34

    // إصدار NDK المطلوب (مهم لـ flutter_webrtc)
    ndkVersion = "27.0.12077973"

    // ============================================================
    // === إصدارات التطبيق ===
    // ============================================================
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // ============================================================
    // === الإعدادات الافتراضية ===
    // ============================================================
    defaultConfig {
        // معرّف التطبيق (يجب أن يكون فريدًا)
        applicationId = "com.lanphone.app"

        // الحد الأدنى لإصدار أندرويد المدعوم
        // 23 = Android 6.0 (Marshmallow)
        // مطلوب لـ flutter_webrtc و image_picker الحديثين
        minSdk = 23

        // الإصدار المستهدف (مطلوب لـ Google Play)
        targetSdk = 34

        // رقم إصدار التطبيق واسمه
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // دعم Dex المتعدد (لأن عدد الدوال > 64k)
        multiDexEnabled = true
    }

    // ============================================================
    // === أنواع البناء ===
    // ============================================================
    buildTypes {
        release {
            // استخدام توقيع debug حاليًا (يجب تغييره للنشر)
            signingConfig = signingConfigs.getByName("debug")

            // تفعيل تصغير الكود (ProGuard/R8)
            isMinifyEnabled = false
            isShrinkResources = false

            // قواعد ProGuard
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        debug {
            // تفعيل عرض السجلات في وضع التصحيح
            isDebuggable = true
        }
    }

    // ============================================================
    // === إعدادات إضافية ===
    // ============================================================
    // لحل مشاكل تعارض بعض المكتبات
    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1"
            )
        }
    }

    // ============================================================
    // === التعامل مع مشاكل البناء ===
    // ============================================================
    // تجاهل تعارضات الإصدارات في المكتبات
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

// ============================================================
// === إعدادات Flutter ===
// ============================================================
flutter {
    source = "../.."
}
