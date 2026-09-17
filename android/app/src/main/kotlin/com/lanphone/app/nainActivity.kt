package com.lanphone.app

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * ============================================================
 * MainActivity — النشاط الرئيسي للتطبيق
 * ------------------------------------------------
 * يرث من FlutterFragmentActivity لدعم local_auth (البصمة).
 * ⚠️ لا تستخدم FlutterActivity لأنها لا تدعم البصمة.
 * ============================================================
 */
class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ============================================
        // === إعدادات النافذة لشاشة المكالمة ===
        // ============================================
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
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
