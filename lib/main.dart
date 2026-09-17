import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/discovery/device_discovery.dart';
import 'core/discovery/discovered_device.dart';
import 'core/messaging/message_service.dart';
import 'core/providers/theme_provider.dart';
import 'core/rtc/rtc_service.dart';
import 'core/services/activation_service.dart';
import 'core/services/app_lifecycle_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/lock_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/permission_service.dart';
import 'core/services/ringtone_service.dart';
import 'core/signaling/signaling_service.dart';
import 'data/database/database_helper.dart';
import 'ui/screens/activation_screen.dart';
import 'ui/screens/audio_call_screen.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/screens/lock_screen.dart';
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

  // 2) الإشعارات المحلية
  try {
    await LocalNotificationService.instance.init();
    debugPrint('[main] Local notifications initialized');
  } catch (e) {
    debugPrint('[main] Local notifications init error: $e');
  }

  // 3) الأذونات
  try {
    await PermissionService.requestEssentialAtStartup();
  } catch (e) {
    debugPrint('[main] Permission request error: $e');
  }

  // 4) Callkit
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
        // ==========================================
        // 1) مزوّد الثيم
        // ==========================================
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),

        // ==========================================
        // 2) خدمة الرنات
        // ==========================================
        ChangeNotifierProvider<RingtoneService>(
          create: (_) => RingtoneService()..load(),
        ),

        // ==========================================
        // 3) دورة حياة التطبيق
        // ==========================================
        ChangeNotifierProvider<AppLifecycleService>(
          create: (_) => AppLifecycleService(),
        ),

        // ==========================================
        // 4) قفل التطبيق بالبصمة
        // ==========================================
        ChangeNotifierProvider<LockService>(
          create: (_) => LockService(),
        ),

        // ==========================================
        // 5) ✅ خدمة التنشيط
        // ==========================================
        ChangeNotifierProvider<ActivationService>(
          create: (_) => ActivationService(),
        ),

        // ==========================================
        // 6) خدمة إشعارات Callkit
        // ==========================================
        ChangeNotifierProvider<NotificationService>(
          create: (_) => NotificationService(),
        ),

        // ==========================================
        // 7) اكتشاف الأجهزة
        // ==========================================
        ChangeNotifierProvider<DeviceDiscovery>(
          create: (_) => DeviceDiscovery()..start(),
        ),

        // ==========================================
        // 8) Signaling
        // ==========================================
        ChangeNotifierProxyProvider<DeviceDiscovery, SignalingService>(
          create: (_) => SignalingService()..start(),
          update: (_, discovery, signaling) {
            signaling?.attachDiscovery(discovery);
            return signaling ?? SignalingService();
          },
        ),

        // ==========================================
        // 9) RTC
        // ==========================================
        ChangeNotifierProxyProvider2<SignalingService, NotificationService,
            RtcService>(
          create: (_) => RtcService(),
          update: (_, signaling, notification, rtc) {
            rtc?.attachSignaling(signaling);
            rtc?.attachNotification(notification);
            return rtc ?? RtcService();
          },
        ),

        // ==========================================
        // 10) الرسائل
        // ==========================================
        ChangeNotifierProxyProvider3<
            DeviceDiscovery,
            SignalingService,
            AppLifecycleService,
            MessageService>(
          create: (_) => MessageService(),
          update: (_, discovery, signaling, lifecycle, messages) {
            messages?.attach(discovery, signaling);
            messages?.attachLifecycle(lifecycle);
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
  // ============================================
  // === المراجع ===
  // ============================================
  StreamSubscription<RtcEvent>? _rtcSub;
  RtcService? _rtc;
  DeviceDiscovery? _discovery;
  bool _callScreenOpen = false;

  // ============================================
  // === دورة الحياة ===
  // ============================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupListeners();
      _setupNotificationTapHandler();
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

  void _setupNotificationTapHandler() {
    LocalNotificationService.instance.onMessageTap = (
      peerDeviceId,
      messageId,
    ) {
      _openChatFromNotification(peerDeviceId, messageId);
    };
  }

  // ============================================
  // === فتح محادثة من إشعار ===
  // ============================================

  void _openChatFromNotification(
    String peerDeviceId,
    String? messageId,
  ) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final peer = _discovery?.getDevice(peerDeviceId);
    if (peer == null) {
      debugPrint('[AppRoot] Peer not found: $peerDeviceId');
      return;
    }

    debugPrint(
      '[AppRoot] Opening chat from notification: $peerDeviceId',
    );

    nav.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peer: peer,
          highlightMessageId: messageId,
        ),
      ),
    );
  }

  // ============================================
  // === أحداث RTC ===
  // ============================================

  void _onRtcEvent(RtcEvent event) {
    switch (event.type) {
      case RtcEventType.incomingCall:
        // Callkit يعرض الواجهة تلقائيًا
        debugPrint('[AppRoot] Incoming call — Callkit handles UI');
        break;

      case RtcEventType.callAccepted:
        _openCallScreen(event);
        break;

      case RtcEventType.callEnded:
        _callScreenOpen = false;
        break;

      default:
        break;
    }
  }

  void _openCallScreen(RtcEvent event) {
    if (_callScreenOpen) return;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final peer = _discovery?.getDevice(event.peerDeviceId);
    if (peer == null) return;

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

      // ==========================================
      // ✅ بوابة التنشيط + القفل
      // ==========================================
      builder: (context, child) {
        return _AppGates(child: child ?? const SizedBox.shrink());
      },

      home: const SplashScreen(),
    );
  }
}

// ============================================================
// === بوابات التطبيق (التنشيط + القفل) ===
// ============================================================
class _AppGates extends StatelessWidget {
  final Widget child;

  const _AppGates({required this.child});

  @override
  Widget build(BuildContext context) {
    // ============================================
    // === 1) فحص التنشيط ===
    // ============================================
    final activation = context.watch<ActivationService>();

    // جارٍ التحقق → عرض شاشة تحميل
    if (activation.checking) {
      return const _LoadingGate();
    }

    // غير مُنشَّط → شاشة التنشيط
    if (!activation.activated) {
      return const ActivationScreen();
    }

    // ============================================
    // === 2) بوابة القفل (فقط إذا نشِط) ===
    // ============================================
    final locked = context.select<LockService, bool>(
      (s) => s.isLocked,
    );

    // أثناء مكالمة نشطة → لا تقفل
    final inCall = context.select<RtcService, bool>(
      (r) => r.isInCall,
    );

    return Stack(
      children: [
        child,
        if (locked && !inCall)
          const Positioned.fill(
            child: LockScreen(),
          ),
      ],
    );
  }
}

// ============================================================
// === شاشة التحميل المؤقتة ===
// ============================================================
class _LoadingGate extends StatelessWidget {
  const _LoadingGate();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A1A1F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'جارٍ التحقق...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
