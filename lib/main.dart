import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/discovery/device_discovery.dart';
import 'core/messaging/message_service.dart';
import 'core/rtc/rtc_service.dart';
import 'core/services/permission_service.dart';
import 'core/signaling/signaling_service.dart';
import 'data/database/database_helper.dart';
import 'ui/screens/incoming_call_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/app_theme.dart';

// ============================================================
// === مفتاح التنقل العام ===
// يُستخدم للتنقل من خارج شجرة الواجهة (مثل: فتح شاشة مكالمة
// واردة من مستمع Stream)
// ============================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ============================================================
// === نقطة الدخول الرئيسية ===
// ============================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // قفل اتجاه الشاشة عموديًا افتراضيًا
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // --------------------------------------------------------
  // 1) تهيئة قاعدة البيانات
  // --------------------------------------------------------
  try {
    await DatabaseHelper.instance.init();
  } catch (e) {
    debugPrint('[main] Database init error: $e');
  }

  // --------------------------------------------------------
  // 2) طلب الأذونات الأساسية (الاكتشاف + الإشعارات)
  // --------------------------------------------------------
  try {
    await PermissionService.requestEssentialAtStartup();
  } catch (e) {
    debugPrint('[main] Permission request error: $e');
  }

  runApp(const LanPhoneApp());
}

// ============================================================
// === التطبيق الرئيسي ===
// ============================================================
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
          create: (_) => SignalingService()..start(),
          update: (_, discovery, signaling) {
            signaling?.attachDiscovery(discovery);
            return signaling ?? SignalingService();
          },
        ),

        // 3) خدمة WebRTC (الصوت والفيديو)
        ChangeNotifierProxyProvider<SignalingService, RtcService>(
          create: (_) => RtcService(),
          update: (_, signaling, rtc) {
            rtc?.attachSignaling(signaling);
            return rtc ?? RtcService();
          },
        ),

        // 4) خدمة الرسائل والوسائط
        ChangeNotifierProxyProvider2<DeviceDiscovery, SignalingService,
            MessageService>(
          create: (_) => MessageService(),
          update: (_, discovery, signaling, messages) {
            messages?.attach(discovery, signaling);
            return messages ?? MessageService();
          },
        ),
      ],
      child: const _AppRoot(),
    );
  }
}

// ============================================================
// === جذر التطبيق (يحتوي على MaterialApp ومستمع المكالمات) ===
// ============================================================
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  StreamSubscription<RtcEvent>? _rtcSub;
  RtcService? _rtc;

  // راقب شاشة المكالمة الواردة الحالية لمنع تكرار فتحها
  bool _incomingScreenOpen = false;

  @override
  void initState() {
    super.initState();

    // تأخير بسيط حتى تكتمل تهيئة الـ Providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRtcListener();
    });
  }

  @override
  void dispose() {
    _rtcSub?.cancel();
    super.dispose();
  }

  // ============================================
  // === مستمع أحداث WebRTC ===
  // ============================================

  void _setupRtcListener() {
    if (!mounted) return;

    _rtc = context.read<RtcService>();
    _rtcSub = _rtc!.events.listen(_onRtcEvent);
  }

  void _onRtcEvent(RtcEvent event) {
    switch (event.type) {
      case RtcEventType.incomingCall:
        _openIncomingCallScreen(event);
        break;

      case RtcEventType.callEnded:
        // إذا كانت شاشة المكالمة الواردة مفتوحة، دعها تُغلق نفسها
        _incomingScreenOpen = false;
        break;

      default:
        break;
    }
  }

  // ============================================
  // === فتح شاشة المكالمة الواردة ===
  // ============================================

  void _openIncomingCallScreen(RtcEvent event) {
    // منع فتح نسختين
    if (_incomingScreenOpen) return;

    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[AppRoot] Navigator not ready — ignoring incoming call');
      return;
    }

    _incomingScreenOpen = true;

    nav
        .push(
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callId: event.callId,
          peerDeviceId: event.peerDeviceId,
          peerName: event.peerName,
          callType: event.callType,
        ),
      ),
    )
        .then((_) {
      // عند إغلاق الشاشة، نُفرِّغ العلم
      _incomingScreenOpen = false;
    });
  }

  // ============================================
  // === الواجهة ===
  // ============================================

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // مفتاح التنقل العالمي
      navigatorKey: navigatorKey,

      // ==========================================
      // === الثيم ===
      // ==========================================
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // ==========================================
      // === اللغة ===
      // ==========================================
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],

      // ==========================================
      // === دعم التوطين (localizations) ===
      // ==========================================
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ==========================================
      // === الشاشة الافتتاحية ===
      // ==========================================
      home: const SplashScreen(),
    );
  }
}
