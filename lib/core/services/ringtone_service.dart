import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// أنواع الرنات المتاحة
/// ============================================================
enum RingtoneType {
  /// نغمة المكالمات الافتراضية للنظام
  ringtone,

  /// نغمة المنبه
  alarm,

  /// نغمة الإشعار
  notification,

  /// صامت تمامًا
  silent,
}

extension RingtoneTypeExt on RingtoneType {
  String get label {
    switch (this) {
      case RingtoneType.ringtone:
        return 'نغمة المكالمات';
      case RingtoneType.alarm:
        return 'نغمة المنبه';
      case RingtoneType.notification:
        return 'نغمة الإشعار';
      case RingtoneType.silent:
        return 'صامت';
    }
  }

  String get description {
    switch (this) {
      case RingtoneType.ringtone:
        return 'نغمة الرنين الافتراضية للهاتف';
      case RingtoneType.alarm:
        return 'نغمة المنبه القوية';
      case RingtoneType.notification:
        return 'نغمة إشعار خفيفة';
      case RingtoneType.silent:
        return 'بدون صوت (اهتزاز فقط)';
    }
  }

  String get storageKey {
    switch (this) {
      case RingtoneType.ringtone:
        return 'ringtone';
      case RingtoneType.alarm:
        return 'alarm';
      case RingtoneType.notification:
        return 'notification';
      case RingtoneType.silent:
        return 'silent';
    }
  }
}

/// ============================================================
/// خدمة الرنات
/// ------------------------------------------------
/// تدير اختيار نوع الرنين وتشغيله/إيقافه
/// ============================================================
class RingtoneService extends ChangeNotifier {
  // ============================================
  // === Singleton ===
  // ============================================
  RingtoneService._internal();
  static final RingtoneService instance = RingtoneService._internal();

  static const String _keyRingtoneType = 'ringtone_type';

  // ============================================
  // === الحالة ===
  // ============================================
  RingtoneType _type = RingtoneType.ringtone;
  RingtoneType get type => _type;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  // ============================================
  // === التهيئة ===
  // ============================================

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyRingtoneType) ?? 'ringtone';
      _type = _fromString(saved);
      debugPrint('[Ringtone] Loaded: ${_type.label}');
      notifyListeners();
    } catch (e) {
      debugPrint('[Ringtone] load error: $e');
    }
  }

  // ============================================
  // === التعديل ===
  // ============================================

  Future<void> setType(RingtoneType type) async {
    if (_type == type) return;

    _type = type;
    notifyListeners();

    try {
      // أوقف أي تشغيل حالي
      await FlutterRingtonePlayer().stop();
      _isPlaying = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRingtoneType, type.storageKey);
      debugPrint('[Ringtone] Changed to: ${type.label}');
    } catch (e) {
      debugPrint('[Ringtone] setType error: $e');
    }
  }

  // ============================================
  // === المعاينة ===
  // ============================================

  /// معاينة قصيرة (تشغيل مرة واحدة)
  Future<void> preview(RingtoneType type) async {
    try {
      // أوقف أي تشغيل سابق
      await FlutterRingtonePlayer().stop();

      switch (type) {
        case RingtoneType.ringtone:
          await FlutterRingtonePlayer().playRingtone(
            looping: false,
            volume: 1.0,
          );
          break;
        case RingtoneType.alarm:
          await FlutterRingtonePlayer().playAlarm(
            looping: false,
            volume: 1.0,
          );
          break;
        case RingtoneType.notification:
          await FlutterRingtonePlayer().playNotification(
            volume: 1.0,
          );
          break;
        case RingtoneType.silent:
          // لا شيء
          break;
      }
    } catch (e) {
      debugPrint('[Ringtone] preview error: $e');
    }
  }

  // ============================================
  // === الرنين للمكالمات ===
  // ============================================

  /// بدء الرنين (للمكالمات الواردة)
  Future<void> startRinging() async {
    if (_type == RingtoneType.silent) {
      debugPrint('[Ringtone] Silent — no ring');
      return;
    }

    try {
      switch (_type) {
        case RingtoneType.ringtone:
          await FlutterRingtonePlayer().playRingtone(
            looping: true,
            volume: 1.0,
          );
          break;
        case RingtoneType.alarm:
          await FlutterRingtonePlayer().playAlarm(
            looping: true,
            volume: 1.0,
          );
          break;
        case RingtoneType.notification:
          await FlutterRingtonePlayer().playNotification(
            looping: true,
            volume: 1.0,
          );
          break;
        case RingtoneType.silent:
          break;
      }
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[Ringtone] startRinging error: $e');
    }
  }

  /// إيقاف الرنين
  Future<void> stopRinging() async {
    try {
      await FlutterRingtonePlayer().stop();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[Ringtone] stopRinging error: $e');
    }
  }

  // ============================================
  // === نغمة الرنين للـ Callkit ===
  // ============================================

  /// إرجاع اسم نغمة النظام لـ Callkit
  /// (Callkit يدعم فقط نغمات النظام الرسمية)
  String get callkitRingtonePath {
    switch (_type) {
      case RingtoneType.ringtone:
        return 'system_ringtone_default';
      case RingtoneType.alarm:
        return 'system_ringtone_default'; // Callkit لا يدعم alarm
      case RingtoneType.notification:
        return 'system_ringtone_default';
      case RingtoneType.silent:
        return 'system_ringtone_default';
    }
  }

  // ============================================
  // === أدوات داخلية ===
  // ============================================

  RingtoneType _fromString(String s) {
    switch (s) {
      case 'alarm':
        return RingtoneType.alarm;
      case 'notification':
        return RingtoneType.notification;
      case 'silent':
        return RingtoneType.silent;
      default:
        return RingtoneType.ringtone;
    }
  }
}
