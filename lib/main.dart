import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/discovery/device_discovery.dart';
import 'core/messaging/message_service.dart';
import 'core/providers/theme_provider.dart';
import 'core/rtc/rtc_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/permission_service.dart';
import 'core/signaling/signaling_service.dart';
import 'data/database/database_helper.dart';
import 'ui/screens/audio_call_screen.dart';
import 'ui/screens/incoming_call_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/video_call_screen.dart';
import 'ui/theme/app_theme.dart';

// ============================================================
// === مفتاح التنقل العام ===
// ============================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ============================================================
// === نقطة الدخول ===
// ============================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 1) قاعدة البيانات
  try {
    await DatabaseHelper.instance.init();
  } catch (e) {
    debugPrint('[main] Database init error: $e');
  }

  // 2) الأذونات الأساسية
  try {
    await PermissionService.requestEssentialAtStartup();
  } catch (e) {
    debugPrint('[main] Permission request error: $e');
  }

  // 3) تهيئة Callkit
  try {
    await FlutterCallkitIncoming.setCallkitIncomingAppName('LanPhone');
    debugPrint('[main] Callkit initialized');
  } catch (e) {
    debugPrint('[main] Callkit init error: $e');
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
        // 1) مزوّد الثيم
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),

        // 2) خدمة الإشعارات (Callkit)
        ChangeNotifierProvider<NotificationService>(
          create: (_) => NotificationService(),
        ),

        // 3) خدمة اكتشاف الأجهزة
        ChangeNotifierProvider<DeviceDiscovery>(
          create: (_) => DeviceDiscovery()..start(),
        ),

        // 4) خدمة التحكم
        ChangeNotifierProxyProvider<DeviceDiscovery, SignalingService>(
          create: (_) => SignalingService()..start(),
          update: (_, discovery, signaling) {
            signaling?.attachDiscovery(discovery);
            return signaling ?? SignalingService();
          },
        ),

        // 5) خدمة WebRTC (يحتاج Signaling + Notification)
        ChangeNotifierProxyProvider2<SignalingService, NotificationService,
            RtcService>(
          create: (_) => RtcService(),
          update: (_, signaling, notification, rtc) {
            rtc?.attachSignaling(signaling);
            rtc?.attachNotification(notification);
            return rtc ?? RtcService();
          },
        ),

        // 6) خدمة الرسائل
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
// === جذر التطبيق ===
// ============================================================
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  StreamSubscription<RtcEvent>? _rtcSub;
  RtcService? _rtc;
  DeviceDiscovery? _discovery;
  bool _callScreenOpen = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupListeners();
    });
  }

  @override
  void dispose() {
    _rtcSub?.cancel();
    super.dispose();
  }

  // ============================================
  // === الإعداد ===
  // ============================================

  void _setupListeners() {
    if (!mounted) return;
    _rtc = context.read<RtcService>();
    _discovery = context.read<DeviceDiscovery>();
    _rtcSub = _rtc!.events.listen(_onRtcEvent);
  }

  void _onRtcEvent(RtcEvent event) {
    switch (event.type) {
      case RtcEventType.incomingCall:
        // ✅ لا نفتح شاشة Flutter — Callkit يعرض الواجهة تلقائيًا
        debugPrint('[AppRoot] Incoming call — Callkit is handling it');
        break;

      case RtcEventType.callAccepted:
        // ✅ المستخدم قبل المكالمة → افتح شاشة المكالمة
        _openCallScreen(event);
        break;

      case RtcEventType.callEnded:
        _callScreenOpen = false;
        break;

      default:
        break;
    }
  }

  // ============================================
  // === فتح شاشة المكالمة بعد القبول ===
  // ============================================

  void _openCallScreen(RtcEvent event) {
    if (_callScreenOpen) return;

    final nav = navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[AppRoot] Navigator not ready');
      return;
    }

    final peer = _discovery?.getDevice(event.peerDeviceId);
    if (peer == null) {
      debugPrint('[AppRoot] Peer not found: ${event.peerDeviceId}');
      return;
    }

    _callScreenOpen = true;

    final Widget screen = event.callType == AppConstants.callTypeVideo
        ? VideoCallScreen(peer: peer, isCaller: false)
        : AudioCallScreen(peer: peer, isCaller: false);

    nav
        .push(
      MaterialPageRoute(builder: (_) => screen),
    )
        .then((_) {
      _callScreenOpen = false;
    });
  }

  // ============================================
  // === الواجهة ===
  // ============================================

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().themeMode;

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
