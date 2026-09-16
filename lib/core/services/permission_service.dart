import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// ============================================================
/// خدمة إدارة الأذونات
/// تتعامل مع الفروق بين إصدارات Android وتطلب الأذونات بذكاء
/// ============================================================
class PermissionService {
  PermissionService._();

  // ============================================
  // === الأذونات المطلوبة حسب المجموعة ===
  // ============================================

  /// أذونات لاكتشاف الأجهزة على الشبكة المحلية
  static List<Permission> get _discoveryPermissions {
    final list = <Permission>[
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ];

    // multicast يحتاج CHANGE_WIFI_MULTICAST_STATE (لا يوجد enum مباشر)
    // نتعامل معه في AndroidManifest فقط
    return list;
  }

  /// أذونات المكالمات الصوتية
  static List<Permission> get _audioCallPermissions => [
        Permission.microphone,
        Permission.bluetoothConnect,
      ];

  /// أذونات مكالمات الفيديو
  static List<Permission> get _videoCallPermissions => [
        Permission.microphone,
        Permission.camera,
        Permission.bluetoothConnect,
      ];

  /// أذونات الوسائط والملفات
  static List<Permission> get _mediaPermissions {
    // Android 13+ يستخدم أذونات منفصلة للصور/الفيديو/الصوت
    if (Platform.isAndroid) {
      return [
        Permission.photos,
        Permission.videos,
        Permission.audio,
        Permission.storage,
      ];
    }
    return [Permission.photos, Permission.storage];
  }

  /// أذونات الإشعارات
  static List<Permission> get _notificationPermissions => [
        Permission.notification,
      ];

  // ============================================
  // === الطلب الأساسي ===
  // ============================================

  /// طلب مجموعة أذونات دفعة واحدة
  /// يُرجع true إذا مُنحت كل الأذونات
  static Future<bool> requestAll(List<Permission> permissions) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    try {
      // نطلب كل الأذونات دفعة واحدة
      final statuses = await permissions.request();

      // نتحقق: هل كل الأذونات المقبولة مُمنوحة؟
      for (final status in statuses.values) {
        if (!status.isGranted && !status.isLimited) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('[Permissions] requestAll error: $e');
      return false;
    }
  }

  /// فحص هل كل الأذونات مُمنوحة (بدون طلب)
  static Future<bool> checkAll(List<Permission> permissions) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    try {
      for (final p in permissions) {
        final status = await p.status;
        if (!status.isGranted && !status.isLimited) {
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint('[Permissions] checkAll error: $e');
      return false;
    }
  }

  // ============================================
  // === طلبات جاهزة (High-Level) ===
  // ============================================

  /// طلب أذونات الاكتشاف (يُطلب عند بدء التطبيق)
  static Future<bool> requestDiscovery() async {
    return requestAll(_discoveryPermissions);
  }

  /// طلب أذونات المكالمة الصوتية
  static Future<bool> requestAudioCall() async {
    return requestAll(_audioCallPermissions);
  }

  /// طلب أذونات مكالمة الفيديو
  static Future<bool> requestVideoCall() async {
    return requestAll(_videoCallPermissions);
  }

  /// طلب أذونات الوسائط
  static Future<bool> requestMedia() async {
    return requestAll(_mediaPermissions);
  }

  /// طلب أذونات الإشعارات
  static Future<bool> requestNotifications() async {
    return requestAll(_notificationPermissions);
  }

  /// طلب **كل** الأذونات دفعة واحدة (عند أول تشغيل)
  /// نطلب الأساسية أولًا ثم الكمالية
  static Future<PermissionSummary> requestEssentialAtStartup() async {
    final discoveryOk = await requestDiscovery();
    final notificationsOk = await requestNotifications();

    return PermissionSummary(
      discoveryGranted: discoveryOk,
      notificationsGranted: notificationsOk,
      audioCallGranted: false,
      videoCallGranted: false,
      mediaGranted: false,
    );
  }

  // ============================================
  // === فحوصات سريعة (بدون طلب) ===
  // ============================================

  static Future<bool> hasMicPermission() async {
    final s = await Permission.microphone.status;
    return s.isGranted;
  }

  static Future<bool> hasCameraPermission() async {
    final s = await Permission.camera.status;
    return s.isGranted;
  }

  static Future<bool> hasDiscoveryPermission() async {
    return checkAll(_discoveryPermissions);
  }

  static Future<bool> hasMediaPermission() async {
    return checkAll(_mediaPermissions);
  }

  // ============================================
  // === تفاصيل مفيدة ===
  // ============================================

  /// هل أحد الأذونات "مرفوض نهائيًا"؟
  /// (يعني: المستخدم اختار "لا تسأل مجددًا")
  static Future<bool> isPermanentlyDenied(
    List<Permission> permissions,
  ) async {
    for (final p in permissions) {
      final status = await p.status;
      if (status.isPermanentlyDenied) return true;
    }
    return false;
  }

  /// فتح إعدادات التطبيق (لتفعيل الأذونات المرفوضة نهائيًا)
  static Future<bool> openAppSettings() async {
    return openAppSettings();
  }

  // ============================================
  // === طلب ذكي مع إرشاد المستخدم ===
  // ============================================

  /// طلب أذونات مع عرض حالة مخصّصة
  /// إذا رُفضت نهائيًا، يُوجّه المستخدم للإعدادات
  static Future<PermissionResult> requestWithGuidance(
    List<Permission> permissions,
    String reason,
  ) async {
    // 1) هل مُمنوحة أصلًا؟
    if (await checkAll(permissions)) {
      return PermissionResult.alreadyGranted();
    }

    // 2) هل مرفوضة نهائيًا؟
    if (await isPermanentlyDenied(permissions)) {
      return PermissionResult.permanentlyDenied();
    }

    // 3) اطلبها
    final granted = await requestAll(permissions);
    if (granted) {
      return PermissionResult.granted();
    }

    // 4) رُفضت للتو
    if (await isPermanentlyDenied(permissions)) {
      return PermissionResult.permanentlyDenied();
    }

    return PermissionResult.denied();
  }
}

// ============================================================
// === نماذج النتائج ===
// ============================================================

class PermissionSummary {
  final bool discoveryGranted;
  final bool notificationsGranted;
  final bool audioCallGranted;
  final bool videoCallGranted;
  final bool mediaGranted;

  const PermissionSummary({
    required this.discoveryGranted,
    required this.notificationsGranted,
    required this.audioCallGranted,
    required this.videoCallGranted,
    required this.mediaGranted,
  });

  bool get isEssentialOk => discoveryGranted;
}

enum PermissionResultStatus {
  alreadyGranted,
  granted,
  denied,
  permanentlyDenied,
}

class PermissionResult {
  final PermissionResultStatus status;

  PermissionResult._(this.status);

  factory PermissionResult.alreadyGranted() =>
      PermissionResult._(PermissionResultStatus.alreadyGranted);

  factory PermissionResult.granted() =>
      PermissionResult._(PermissionResultStatus.granted);

  factory PermissionResult.denied() =>
      PermissionResult._(PermissionResultStatus.denied);

  factory PermissionResult.permanentlyDenied() =>
      PermissionResult._(PermissionResultStatus.permanentlyDenied);

  bool get isOk =>
      status == PermissionResultStatus.granted ||
      status == PermissionResultStatus.alreadyGranted;

  bool get shouldOpenSettings =>
      status == PermissionResultStatus.permanentlyDenied;
}
