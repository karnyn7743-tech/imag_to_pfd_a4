import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../discovery/discovered_device.dart';

/// ============================================================
/// خدمة ترميز وفك ترميز بيانات QR
/// ============================================================
class QrService {
  QrService._();

  /// إصدار الصيغة الحالي
  static const int _formatVersion = 1;

  // ============================================
  // === الترميز (إنشاء QR) ===
  // ============================================

  /// تحويل معلومات الجهاز إلى نص JSON للـ QR
  static String encode({
    required String deviceId,
    required String number,
    required String name,
    required String ip,
    required int port,
    List<String> capabilities = const [
      'text',
      'voice',
      'video',
      'media',
    ],
  }) {
    final data = {
      'v': _formatVersion,
      'id': deviceId,
      'n': number,
      'name': name,
      'ip': ip,
      'port': port,
      'caps': capabilities,
    };

    return jsonEncode(data);
  }

  // ============================================
  // === فك الترميز (قراءة QR) ===
  // ============================================

  /// تحليل نص QR إلى نموذج جهاز
  /// يُرجع `null` إذا كان النص غير صالح
  static QrDeviceData? decode(String raw) {
    try {
      final trimmed = raw.trim();

      // يجب أن يبدأ بـ { (JSON)
      if (!trimmed.startsWith('{')) {
        debugPrint('[QR] Not a LanPhone QR');
        return null;
      }

      final Map<String, dynamic> data =
          jsonDecode(trimmed) as Map<String, dynamic>;

      // تحقق من الإصدار
      final version = data['v'] as int?;
      if (version == null || version > _formatVersion) {
        debugPrint('[QR] Unsupported version: $version');
        return null;
      }

      // تحقق من الحقول المطلوبة
      final deviceId = data['id'] as String?;
      final number = data['n'] as String?;
      final name = data['name'] as String?;

      if (deviceId == null || deviceId.isEmpty) {
        debugPrint('[QR] Missing deviceId');
        return null;
      }

      if (name == null || name.isEmpty) {
        debugPrint('[QR] Missing name');
        return null;
      }

      final ip = data['ip'] as String? ?? '';
      final port = (data['port'] as num?)?.toInt() ??
          AppConstants.signalingPort;
      final caps = (data['caps'] as List?)?.cast<String>() ??
          const ['text', 'voice', 'video', 'media'];

      return QrDeviceData(
        deviceId: deviceId,
        number: number ?? '',
        name: name,
        ip: ip,
        port: port,
        capabilities: caps,
      );
    } catch (e) {
      debugPrint('[QR] Decode error: $e');
      return null;
    }
  }

  // ============================================
  // === التحقق من الصلاحية ===
  // ============================================

  /// هل هذا النص QR صالح للتطبيق؟
  static bool isValidQr(String raw) {
    return decode(raw) != null;
  }
}

// ============================================================
// === نموذج البيانات المُستخرجة من QR ===
// ============================================================
class QrDeviceData {
  final String deviceId;
  final String number;
  final String name;
  final String ip;
  final int port;
  final List<String> capabilities;

  const QrDeviceData({
    required this.deviceId,
    required this.number,
    required this.name,
    required this.ip,
    required this.port,
    required this.capabilities,
  });

  /// تحويل إلى `DiscoveredDevice` (بحالة "غير متصل" حتى يتم اكتشافه)
  DiscoveredDevice toDiscoveredDevice({bool isOnline = false}) {
    return DiscoveredDevice(
      deviceId: deviceId,
      number: number,
      name: name,
      ip: ip,
      port: port,
      capabilities: capabilities,
      lastSeen: DateTime.now(),
      isOnline: isOnline,
    );
  }

  @override
  String toString() =>
      'QrDeviceData($name, #$number, $ip:$port)';
}
