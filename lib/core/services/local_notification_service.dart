import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// ============================================================
/// خدمة الإشعارات المحلية
/// ------------------------------------------------
/// تعرض إشعارات للرسائل الجديدة والتنبيهات
/// وتفتح المحادثة عند الضغط على الإشعار
/// ============================================================
class LocalNotificationService {
  // ============================================
  // === Singleton ===
  // ============================================
  LocalNotificationService._internal();
  static final LocalNotificationService instance =
      LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ============================================
  // === Callbacks للتنقل ===
  // ============================================
  /// يُستدعى عند الضغط على إشعار رسالة
  /// يُمرَّر: (peerDeviceId, messageId)
  Function(String peerDeviceId, String? messageId)? onMessageTap;

  /// قناة الرسائل
  static const String _messageChannelId = 'lanphone_messages';
  static const String _messageChannelName = 'الرسائل';
  static const String _messageChannelDesc =
      'إشعارات الرسائل الجديدة';

  // ============================================
  // === التهيئة ===
  // ============================================

  Future<void> init() async {
    if (_initialized) return;

    // إعدادات أندرويد
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // إعدادات iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundNotificationResponse,
      );

      // قناة أندرويد للرسائل
      await _createAndroidChannel();

      _initialized = true;
      debugPrint('[Notifications] Initialized');
    } catch (e) {
      debugPrint('[Notifications] init error: $e');
    }
  }

  Future<void> _createAndroidChannel() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // قناة الرسائل
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _messageChannelId,
        _messageChannelName,
        description: _messageChannelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
  }

  // ============================================
  // === معالجة الضغط على الإشعار ===
  // ============================================

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final peerDeviceId = data['peerDeviceId'] as String?;
      final messageId = data['messageId'] as String?;

      if (peerDeviceId != null) {
        debugPrint(
          '[Notifications] Tapped: peer=$peerDeviceId, '
          'msg=$messageId',
        );
        onMessageTap?.call(peerDeviceId, messageId);
      }
    } catch (e) {
      debugPrint('[Notifications] parse payload error: $e');
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(
    NotificationResponse response,
  ) {
    // في الخلفية — المعالجة تتم عند فتح التطبيق
    debugPrint('[Notifications] Background tap: ${response.payload}');
  }

  // ============================================
  // === عرض إشعار رسالة ===
  // ============================================

  /// عرض إشعار رسالة جديدة
  ///
  /// [peerDeviceId] معرّف الجهاز المرسل
  /// [peerName] اسم المرسل
  /// [peerNumber] رقم المرسل (اختياري)
  /// [body] نص الرسالة أو وصف
  /// [messageId] معرّف الرسالة (للانتقال إليها)
  /// [conversationId] للاستخدام في التجميع
  Future<void> showMessageNotification({
    required String peerDeviceId,
    required String peerName,
    String? peerNumber,
    required String body,
    String? messageId,
    String? conversationId,
  }) async {
    if (!_initialized) await init();

    try {
      // عنوان الإشعار
      final title = peerNumber != null && peerNumber.isNotEmpty
          ? '$peerName • #$peerNumber'
          : peerName;

      // محتوى الإشعار (قصير)
      final preview = _truncate(body, 100);

      // Payload للتنقل
      final payload = jsonEncode({
        'peerDeviceId': peerDeviceId,
        'messageId': messageId,
        'conversationId': conversationId,
        'type': 'message',
      });

      // إعدادات أندرويد
      final androidDetails = AndroidNotificationDetails(
        _messageChannelId,
        _messageChannelName,
        channelDescription: _messageChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(
          preview,
          contentTitle: title,
          summaryText: 'LanPhone',
        ),
        // تجميع الإشعارات حسب المحادثة
        groupKey: conversationId ?? peerDeviceId,
        autoCancel: true,
        onlyAlertOnce: false,
      );

      // إعدادات iOS
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.active,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // معرّف الإشعار: نستخدم hash لـ deviceId
      // (لتحديث نفس الإشعار في نفس المحادثة بدل تراكمها)
      final notificationId = peerDeviceId.hashCode & 0x7FFFFFFF;

      await _plugin.show(
        notificationId,
        title,
        preview,
        details,
        payload: payload,
      );

      debugPrint('[Notifications] Message shown from $peerName');
    } catch (e) {
      debugPrint('[Notifications] showMessage error: $e');
    }
  }

  // ============================================
  // === إلغاء الإشعارات ===
  // ============================================

  /// إلغاء إشعار محادثة محددة
  /// (يُستدعى عند فتح المحادثة)
  Future<void> cancelForDevice(String peerDeviceId) async {
    if (!_initialized) return;

    try {
      final id = peerDeviceId.hashCode & 0x7FFFFFFF;
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('[Notifications] cancel error: $e');
    }
  }

  /// إلغاء كل الإشعارات
  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[Notifications] cancelAll error: $e');
    }
  }

  // ============================================
  // === طلب الأذونات ===
  // ============================================

  Future<bool> requestPermission() async {
    if (!_initialized) await init();

    try {
      if (Platform.isAndroid) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted =
            await androidPlugin?.requestNotificationsPermission();
        return granted ?? false;
      }

      if (Platform.isIOS) {
        final iosPlugin = _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      return true;
    } catch (e) {
      debugPrint('[Notifications] requestPermission error: $e');
      return false;
    }
  }

  // ============================================
  // === أدوات ===
  // ============================================

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
