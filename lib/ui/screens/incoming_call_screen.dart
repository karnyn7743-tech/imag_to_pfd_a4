import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/discovery/device_discovery.dart';
import '../../core/rtc/rtc_service.dart';
import '../theme/app_theme.dart';
import 'audio_call_screen.dart';
import 'video_call_screen.dart';

/// ============================================================
/// شاشة المكالمة الواردة
/// تُفتح تلقائيًا من HomeScreen عندما يصل حدث incomingCall
/// ============================================================
class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String peerDeviceId;
  final String peerName;
  final String callType;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.peerDeviceId,
    required this.peerName,
    required this.callType,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  // ============================================
  // === المراجع ===
  // ============================================
  RtcService? _rtc;
  StreamSubscription<RtcEvent>? _rtcEventSub;
  Timer? _timeoutTimer;

  // ============================================
  // === الحالة ===
  // ============================================
  bool _isHandling = false;

  // ============================================
  // === الأنيميشن ===
  // ============================================
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ============================================
  // === دورة الحياة ===
  // ============================================

  @override
  void initState() {
    super.initState();

    // إعداد الأنيميشن النبضي
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _rtc = context.read<RtcService>();
      _rtcEventSub = _rtc!.events.listen(_onRtcEvent);

      // ابدأ الرنين والاهتزاز
      await _startRinging();

      // مهلة 45 ثانية → رفض تلقائي
      _timeoutTimer = Timer(
        const Duration(seconds: 45),
        () {
          if (mounted && !_isHandling) {
            _handleTimeout();
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _rtcEventSub?.cancel();
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    _stopRinging();
    super.dispose();
  }

  // ============================================
  // === الرنين ===
  // ============================================

  Future<void> _startRinging() async {
    try {
      if (widget.callType == AppConstants.callTypeVideo) {
        await FlutterRingtonePlayer().playRingtone(
          looping: true,
          volume: 0.9,
        );
      } else {
        await FlutterRingtonePlayer().playRingtone(
          looping: true,
          volume: 0.9,
        );
      }
    } catch (e) {
      debugPrint('[IncomingCall] ringtone error: $e');
    }
  }

  void _stopRinging() {
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
  }

  // ============================================
  // === أحداث RTC ===
  // ============================================

  void _onRtcEvent(RtcEvent event) {
    // إذا أُلغيت المكالمة من الطرف الآخر
    if (event.type == RtcEventType.callEnded &&
        event.callId == widget.callId) {
      _stopRinging();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  // ============================================
  // === القبول ===
  // ============================================

  Future<void> _accept() async {
    if (_isHandling) return;
    _isHandling = true;
    _stopRinging();
    _timeoutTimer?.cancel();

    final ok = await _rtc!.acceptCall();

    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر قبول المكالمة'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    // انتقل لشاشة المكالمة المناسبة
    final discovery = context.read<DeviceDiscovery>();
    final peer = discovery.getDevice(widget.peerDeviceId);

    if (peer == null) {
      Navigator.of(context).pop();
      return;
    }

    // استبدل هذه الشاشة بشاشة المكالمة
    final Widget nextScreen = widget.callType == AppConstants.callTypeVideo
        ? VideoCallScreen(peer: peer, isCaller: false)
        : AudioCallScreen(peer: peer, isCaller: false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  // ============================================
  // === الرفض ===
  // ============================================

  Future<void> _reject() async {
    if (_isHandling) return;
    _isHandling = true;
    _stopRinging();
    _timeoutTimer?.cancel();

    await _rtc!.rejectCall();

    if (mounted) Navigator.of(context).pop();
  }

  void _handleTimeout() {
    // مهلة — نرفض تلقائيًا كـ "لم يُرَد"
    _reject();
  }

  // ============================================
  // === الواجهة ===
  // ============================================

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == AppConstants.callTypeVideo;

    return PopScope(
      canPop: false, // منع الرجوع بالزر
      onPopInvoked: (didPop) {
        if (!didPop && !_isHandling) {
          _reject();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1A1F),
        body: SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F2A2E),
                  Color(0xFF0A1A1F),
                ],
              ),
            ),
            child: Column(
              children: [
                // ============================================
                // === الجزء العلوي: معلومات المتصل ===
                // ============================================
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // نوع المكالمة
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVideo
                                  ? Icons.videocam
                                  : Icons.call_outlined,
                              size: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isVideo
                                  ? 'مكالمة فيديو واردة'
                                  : 'مكالمة صوتية واردة',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // الصورة الرمزية النابضة
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.25),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.5),
                              width: 3,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.peerName.isNotEmpty
                                ? widget.peerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 60,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // اسم المتصل
                      Text(
                        widget.peerName,
                        style: const TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'يتصل بك...',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // ============================================
                // === أزرار القبول/الرفض ===
                // ============================================
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // زر الرفض
                            _ActionButton(
                              icon: Icons.call_end,
                              label: 'رفض',
                              color: AppTheme.errorColor,
                              onTap: _reject,
                            ),

                            // زر القبول (يتحرك بلطف)
                            _PulsingButton(
                              animation: _pulseController,
                              child: _ActionButton(
                                icon: isVideo
                                    ? Icons.videocam
                                    : Icons.call,
                                label: 'قبول',
                                color: AppTheme.successColor,
                                onTap: _accept,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// === زر إجراء (قبول/رفض) ===
// ============================================================
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(
                icon,
                size: 34,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// === زر القبول النابض (لجذب الانتباه) ===
// ============================================================
class _PulsingButton extends StatelessWidget {
  final Widget child;
  final AnimationController animation;

  const _PulsingButton({
    required this.child,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final scale = 1.0 + (animation.value * 0.05);
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}
