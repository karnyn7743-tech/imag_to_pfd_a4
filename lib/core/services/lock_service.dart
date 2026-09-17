import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// فترات القفل التلقائي
/// ============================================================
enum LockDelay {
  immediately, // فورًا
  after30s, // بعد 30 ثانية
  after1min, // بعد دقيقة
  after5min, // بعد 5 دقائق
  never, // أبدًا (يدوي فقط)
}

extension LockDelayExt on LockDelay {
  String get label {
    switch (this) {
      case LockDelay.immediately:
        return 'فورًا';
      case LockDelay.after30s:
        return 'بعد 30 ثانية';
      case LockDelay.after1min:
        return 'بعد دقيقة';
      case LockDelay.after5min:
        return 'بعد 5 دقائق';
      case LockDelay.never:
        return 'أبدًا (قفل يدوي فقط)';
    }
  }

  String get description {
    switch (this) {
      case LockDelay.immediately:
        return 'يُقفل التطبيق عند مغادرته فورًا';
      case LockDelay.after30s:
        return 'يُقفل بعد 30 ثانية من مغادرته';
      case LockDelay.after1min:
        return 'يُقفل بعد دقيقة من مغادرته';
      case LockDelay.after5min:
        return 'يُقفل بعد 5 دقائق من مغادرته';
      case LockDelay.never:
        return 'يُقفل فقط عند إعادة التشغيل';
    }
  }

  Duration? get duration {
    switch (this) {
      case LockDelay.immediately:
        return Duration.zero;
      case LockDelay.after30s:
        return const Duration(seconds: 30);
      case LockDelay.after1min:
        return const Duration(minutes: 1);
      case LockDelay.after5min:
        return const Duration(minutes: 5);
      case LockDelay.never:
        return null;
    }
  }

  String get storageKey {
    switch (this) {
      case LockDelay.immediately:
        return 'immediately';
      case LockDelay.after30s:
        return 'after30s';
      case LockDelay.after1min:
        return 'after1min';
      case LockDelay.after5min:
        return 'after5min';
      case LockDelay.never:
        return 'never';
    }
  }
}

/// ============================================================
/// خدمة قفل التطبيق بالبصمة
/// ============================================================
class LockService extends ChangeNotifier with WidgetsBindingObserver {
  LockService() {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  // ============================================
  // === المفاتيح ===
  // ============================================
  static const String _keyEnabled = 'lock_enabled';
  static const String _keyDelay = 'lock_delay';

  // ============================================
  // === المراجع ===
  // ============================================
  final LocalAuthentication _auth = LocalAuthentication();

  // ============================================
  // === الحالة ===
  // ============================================
  bool _enabled = false;
  bool get enabled => _enabled;

  bool _isLocked = false;
  bool get isLocked => _isLocked;

  bool _isAuthenticating = false;
  bool get isAuthenticating => _isAuthenticating;

  LockDelay _delay = LockDelay.immediately;
  LockDelay get delay => _delay;

  bool _available = false;
  bool get available => _available;

  bool _canCheckBiometrics = false;
  bool get canCheckBiometrics => _canCheckBiometrics;

  List<BiometricType> _biometricTypes = [];
  List<BiometricType> get biometricTypes => _biometricTypes;

  String? _lastError;
  String? get lastError => _lastError;

  DateTime? _backgroundedAt;
  bool _isFirstLaunch = true;

  // ============================================
  // === التهيئة ===
  // ============================================

  Future<void> _load() async {
    try {
      // 1) فحص توفر البصمة
      await _checkAvailability();

      // 2) تحميل الإعدادات
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_keyEnabled) ?? false;

      final delayKey = prefs.getString(_keyDelay) ?? 'immediately';
      _delay = _fromString(delayKey);

      // 3) إذا كان القفل مُفعَّلًا، اقفل التطبيق عند البدء
      if (_enabled) {
        _isLocked = true;
      }

      debugPrint(
        '[Lock] Loaded: enabled=$_enabled, delay=${_delay.label}, '
        'available=$_available',
      );

      notifyListeners();
    } catch (e) {
      debugPrint('[Lock] load error: $e');
    }
  }

  Future<void> _checkAvailability() async {
    try {
      _available = await _auth.isDeviceSupported();
      _canCheckBiometrics = await _auth.canCheckBiometrics;

      if (_available) {
        _biometricTypes = await _auth.getAvailableBiometrics();
      }

      debugPrint(
        '[Lock] Device supported: $_available, '
        'Biometrics: $_canCheckBiometrics, '
        'Types: $_biometricTypes',
      );
    } catch (e) {
      debugPrint('[Lock] checkAvailability error: $e');
      _available = false;
      _canCheckBiometrics = false;
    }
  }

  // ============================================
  // === التعديل ===
  // ============================================

  Future<bool> setEnabled(bool value) async {
    if (value) {
      // اطلب مصادقة لتأكيد التفعيل
      final ok = await _authenticate(
        reason: 'تأكيد تفعيل قفل التطبيق',
      );
      if (!ok) return false;
    }

    _enabled = value;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyEnabled, value);
    } catch (e) {
      debugPrint('[Lock] setEnabled error: $e');
    }

    notifyListeners();
    return true;
  }

  Future<void> setDelay(LockDelay delay) async {
    _delay = delay;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDelay, delay.storageKey);
    } catch (e) {
      debugPrint('[Lock] setDelay error: $e');
    }
    notifyListeners();
  }

  // ============================================
  // === القفل / الفتح ===
  // ============================================

  /// اقفل التطبيق يدويًا
  void lock() {
    if (!_enabled) return;
    if (_isLocked) return;
    _isLocked = true;
    notifyListeners();
  }

  /// افتح التطبيق يدويًا (بدون مصادقة — للاستخدام الداخلي)
  void unlock() {
    if (!_isLocked) return;
    _isLocked = false;
    notifyListeners();
  }

  /// فتح بالمصادقة
  Future<bool> authenticate() async {
    final ok = await _authenticate(
      reason: 'افتح LanPhone للمتابعة',
    );

    if (ok) {
      _isLocked = false;
      _lastError = null;
      notifyListeners();
    }

    return ok;
  }

  // ============================================
  // === المصادقة الداخلية ===
  // ============================================

  Future<bool> _authenticate({required String reason}) async {
    if (_isAuthenticating) return false;

    if (!_available) {
      _lastError = 'البصمة غير متوفرة على هذا الجهاز';
      notifyListeners();
      return false;
    }

    _isAuthenticating = true;
    _lastError = null;
    notifyListeners();

    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // اسمح بـ PIN/Pattern كبديل
          stickyAuth: true, // ابقَ في المقدمة أثناء المصادقة
          useErrorDialogs: true,
        ),
      );

      _isAuthenticating = false;
      notifyListeners();
      return ok;
    } catch (e) {
      debugPrint('[Lock] authenticate error: $e');
      _isAuthenticating = false;
      _lastError = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  String _parseError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('not enrolled') || s.contains('no biometrics')) {
      return 'لا توجد بصمات مسجّلة. أضف بصمة من إعدادات النظام.';
    }
    if (s.contains('locked out') || s.contains('too many')) {
      return 'محاولات كثيرة خاطئة. جرّب لاحقًا.';
    }
    if (s.contains('not available') || s.contains('not supported')) {
      return 'البصمة غير متوفرة على هذا الجهاز.';
    }
    if (s.contains('canceled') || s.contains('cancelled')) {
      return 'أُلغي التحقق.';
    }
    return 'تعذّر التحقق. حاول مجددًا.';
  }

  // ============================================
  // === دورة الحياة ===
  // ============================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // غادر التطبيق → سجّل الوقت
        if (_enabled) {
          _backgroundedAt = DateTime.now();
          _isFirstLaunch = false;
        }
        break;

      case AppLifecycleState.resumed:
        _checkLockOnResume();
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _checkLockOnResume() {
    if (!_enabled) return;
    if (_isLocked) return;
    if (_isFirstLaunch) return;
    if (_backgroundedAt == null) return;

    final delayDuration = _delay.duration;

    // "أبدًا" → لا تقفل تلقائيًا
    if (delayDuration == null) {
      _backgroundedAt = null;
      return;
    }

    final elapsed = DateTime.now().difference(_backgroundedAt!);

    if (elapsed >= delayDuration) {
      _isLocked = true;
      notifyListeners();
      debugPrint('[Lock] Locked (elapsed: ${elapsed.inSeconds}s)');
    }

    _backgroundedAt = null;
  }

  // ============================================
  // === أدوات ===
  // ============================================

  LockDelay _fromString(String s) {
    switch (s) {
      case 'after30s':
        return LockDelay.after30s;
      case 'after1min':
        return LockDelay.after1min;
      case 'after5min':
        return LockDelay.after5min;
      case 'never':
        return LockDelay.never;
      default:
        return LockDelay.immediately;
    }
  }

  /// وصف البصمات المتوفرة (للعرض في الإعدادات)
  String get biometricDescription {
    if (!_available) return 'البصمة غير متوفرة';
    if (_biometricTypes.isEmpty) return 'لم يتم تسجيل بصمات';
    if (_biometricTypes.contains(BiometricType.face)) {
      return 'التعرّف على الوجه';
    }
    if (_biometricTypes.contains(BiometricType.fingerprint)) {
      return 'بصمة الإصبع';
    }
    if (_biometricTypes.contains(BiometricType.iris)) {
      return 'بصمة القزحية';
    }
    return 'المصادقة الحيوية';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
