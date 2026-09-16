import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/discovery/device_discovery.dart';
import 'core/messaging/message_service.dart';
import 'core/rtc/rtc_service.dart';
import 'core/signaling/signaling_service.dart';
import 'data/database/database_helper.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/app_theme.dart';

/// ============================================================
/// نقطة الدخول الرئيسية للتطبيق
/// ============================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // قفل اتجاه الشاشة عموديًا افتراضيًا
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // تهيئة قاعدة البيانات قبل تشغيل التطبيق
  await DatabaseHelper.instance.init();

  runApp(const LanPhoneApp());
}

/// ============================================================
/// التطبيق الرئيسي
/// ============================================================
class LanPhoneApp extends StatelessWidget {
  const LanPhoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ==========================================
        // === خدمات التطبيق الأساسية ===
        // ==========================================

        // 1) خدمة اكتشاف الأجهزة على الشبكة المحلية
        ChangeNotifierProvider<DeviceDiscovery>(
          create: (_) => DeviceDiscovery()..start(),
        ),

        // 2) خدمة التحكم (Signaling) عبر WebSocket
        ChangeNotifierProxyProvider<DeviceDiscovery, SignalingService>(
          create: (_) => SignalingService(),
          update: (_, discovery, signaling) =>
              signaling!..attachDiscovery(discovery),
        ),

        // 3) خدمة WebRTC (الصوت والفيديو)
        ChangeNotifierProxyProvider<SignalingService, RtcService>(
          create: (_) => RtcService(),
          update: (_, signaling, rtc) => rtc!..attachSignaling(signaling),
        ),

        // 4) خدمة الرسائل والوسائط
        ChangeNotifierProxyProvider2<DeviceDiscovery, SignalingService,
            MessageService>(
          create: (_) => MessageService(),
          update: (_, discovery, signaling, messages) =>
              messages!..attach(discovery, signaling),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,

        // الثيم
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,

        // اللغة العربية كلغة افتراضية
        locale: const Locale('ar'),
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
        ],

        // نقطة البداية
        home: const SplashScreen(),
      ),
    );
  }
}
