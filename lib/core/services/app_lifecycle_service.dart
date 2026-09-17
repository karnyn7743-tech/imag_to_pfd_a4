import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// ============================================================
/// خدمة دورة حياة التطبيق
/// ------------------------------------------------
/// تعرف ما إذا كان التطبيق في المقدمة أم الخلفية،
/// وكذلك المحادثة المفتوحة حاليًا (لتجاهل إشعاراتها)
/// ============================================================
class AppLifecycleService extends ChangeNotifier
    with WidgetsBindingObserver {
  AppLifecycleService() {
    WidgetsBinding.instance.addObserver(this);
  }

  // ============================================
  // === حالة التطبيق ===
  // ============================================
  AppLifecycleState _state = AppLifecycleState.resumed;
  AppLifecycleState get state => _state;

  bool get isInForeground =>
      _state == AppLifecycleState.resumed;

  bool get isInBackground =>
      _state == AppLifecycleState.paused ||
      _state == AppLifecycleState.inactive ||
      _state == AppLifecycleState.detached;

  // ============================================
  // === المحادثة المفتوحة حاليًا ===
  // ============================================
  /// معرّف الجهاز للمحادثة المفتوحة
  String? _openChatPeerId;

  String? get openChatPeerId => _openChatPeerId;

  /// هل هذه المحادثة مفتوحة الآن؟
  bool isChatOpen(String peerDeviceId) =>
      _openChatPeerId == peerDeviceId;

  /// استدعِ عند فتح محادثة
  void setOpenChat(String peerDeviceId) {
    _openChatPeerId = peerDeviceId;
    debugPrint('[Lifecycle] Chat opened: $peerDeviceId');
  }

  /// استدعِ عند إغلاق محادثة
  void clearOpenChat() {
    _openChatPeerId = null;
    debugPrint('[Lifecycle] Chat closed');
  }

  // ============================================
  // === دورة الحياة ===
  // ============================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state = state;
    debugPrint('[Lifecycle] State: $state');
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
