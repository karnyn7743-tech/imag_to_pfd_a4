plugins {
    id("com.android.application")
    id("kotlin-android")
    // يجب تطبيق Flutter Gradle Plugin بعد Android و Kotlin
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
    // === إصدارات Java و Kotlin ===
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
        // معرّف التطبيق (يجب أن يطابق namespace)
        applicationId = "com.lanphone.app"

        // الحد الأدنى لإصدار أندرويد المدعوم
        // 23 = Android 6.0 (Marshmallow)
        minSdk = 23

        // الإصدار المستهدف (مطلوب لـ Google Play)
        targetSdk = 34

        // رقم إصدار التطبيق واسمه
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // دعم Dex المتعدد (لأن عدد الدوال > 64k بسبب WebRTC)
        multiDexEnabled = true

        // ⚠️ مهم: لا تضف manifestPlaceholders هنا
        // Flutter 3.29+ يتولى applicationName تلقائيًا
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
    // === إعدادات الحزم ===
    // ============================================================
    // لحل مشاكل تعارض بعض المكتبات (WebRTC + غيرها)
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
    // === التعامل مع مشاكل البناء ===
    // ============================================================
    // تعطيل فحص lint الصارم (لتجنب فشل البناء بسبب تحذيرات)
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
