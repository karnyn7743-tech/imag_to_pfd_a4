package com.lanphone.app

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

/**
 * ============================================================
 * MainActivity — النشاط الرئيسي للتطبيق
 * ------------------------------------------------
 * يرث من FlutterActivity ويعرض واجهة Flutter.
 * يحتوي على تحسينات صغيرة لعرض شاشة المكالمة فوق شاشة القفل.
 * ============================================================
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ============================================
        // === إعدادات النافذة لشاشة المكالمة ===
        // ============================================
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            // Android 8.1+ — يُظهر الشاشة فوق القفل عند الحاجة
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                        or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        // إبقاء الشاشة مضاءة أثناء المكالمة
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
