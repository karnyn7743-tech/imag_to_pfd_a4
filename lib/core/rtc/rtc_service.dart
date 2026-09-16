import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../constants.dart';
import '../signaling/signaling_service.dart';

/// ============================================================
/// محرك WebRTC لإدارة المكالمات الصوتية والمرئية
/// ------------------------------------------------
/// يعتمد على SignalingService لتبادل SDP/ICE
/// ============================================================
class RtcService extends ChangeNotifier {
  RtcService();

  // ============================================
  // === المراجع الخارجية ===
  // ============================================
  SignalingService? _signaling;
  StreamSubscription<SignalingMessage>? _messageSub;

  void attachSignaling(SignalingService signaling) {
    if (_signaling == signaling) return;
    _messageSub?.cancel();
    _signaling = signaling;
    _messageSub = _signaling!.messages.listen(_onSignalingMessage);
  }

  // ============================================
  // === حالة المكالمة الحالية ===
  // ============================================
  String _currentCallId = '';
  String get currentCallId => _currentCallId;

  String _peerDeviceId = '';
  String get peerDeviceId => _peerDeviceId;

  String _peerName = '';
  String get peerName => _peerName;

  String _callType = AppConstants.callTypeAudio;
  String get callType => _callType;

  String _callState = AppConstants.callStateIdle;
  String get callState => _callState;

  bool get isInCall => _callState != AppConstants.callStateIdle;
  bool get isCaller => _isCaller;
  bool _isCaller = false;

  DateTime? _callStartedAt;
  DateTime? get callStartedAt => _callStartedAt;

  int get callDurationSeconds {
    if (_callStartedAt == null) return 0;
    return DateTime.now().difference(_callStartedAt!).inSeconds;
  }

  // ============================================
  // === حالة الوسائط ===
  // ============================================
  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isVideoEnabled = true;
  bool get isVideoEnabled => _isVideoEnabled;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  bool _isFrontCamera = true;
  bool get isFrontCamera => _isFrontCamera;

  bool _hasRemoteVideo = false;
  bool get hasRemoteVideo => _hasRemoteVideo;

  // ============================================
  // === WebRTC Objects ===
  // ============================================
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  final List<RTCIceCandidate> _pendingCandidates = [];

  // ============================================
  // === الإعدادات ===
  // ============================================
  final Map<String, dynamic> _iceServers = const {
    'iceServers': <Map<String, dynamic>>[
      // شبكة محلية → لا نحتاج STUN/TURN خارجي
    ],
    'sdpSemantics': 'unified-plan',
  };

  final Map<String, dynamic> _audioConstraints = const {
    'audio': {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
      'googEchoCancellation': true,
      'googEchoCancellation2': true,
      'googAutoGainControl': true,
      'googAutoGainControl2': true,
      'googNoiseSuppression': true,
      'googHighpassFilter': true,
      'googTypingNoiseDetection': true,
      // جودة قريبة من GSM
      'sampleRate': AppConstants.audioSampleRate,
      'channelCount': AppConstants.audioChannels,
    },
  };

  final Map<String, dynamic> _videoConstraints = const {
    'video': {
      'mandatory': {
        'minWidth': '320',
        'minHeight': '240',
        'maxWidth': '${AppConstants.videoWidth}',
        'maxHeight': '${AppConstants.videoHeight}',
        'minFrameRate': '15',
        'maxFrameRate': '${AppConstants.videoFps}',
      },
      'optional': <Map<String, dynamic>>[],
    },
  };

  // ============================================
  // === Streams للأحداث ===
  // ============================================
  final StreamController<RtcEvent> _eventController =
      StreamController<RtcEvent>.broadcast();
  Stream<RtcEvent> get events => _eventController.stream;

  // ============================================
  // === بدء مكالمة (نحن المُتصل) ===
  // ============================================

  Future<bool> startCall({
    required String peerDeviceId,
    required String peerName,
    required String callType,
  }) async {
    if (isInCall) {
      debugPrint('[RTC] Already in call');
      return false;
    }

    if (_signaling == null) {
      debugPrint('[RTC] Signaling not attached');
      return false;
    }

    _currentCallId = _generateCallId();
    _peerDeviceId = peerDeviceId;
    _peerName = peerName;
    _callType = callType;
    _isCaller = true;
    _callState = AppConstants.callStateCalling;
    _hasRemoteVideo = false;
    notifyListeners();

    try {
      // 1) فتح الميكروفون/الكاميرا أولًا
      await _openLocalMedia(callType);

      // 2) إنشاء RTCPeerConnection
      await _createPeerConnection();

      // 3) إضافة المسارات
      await _addLocalTracks();

      // 4) إنشاء عرض SDP
      final offer = await _pc!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': callType == AppConstants.callTypeVideo,
      });
      await _pc!.setLocalDescription(offer);

      // 5) إرسال الدعوة عبر Signaling
      await _signaling!.sendTo(peerDeviceId, {
        'type': AppConstants.msgCallInvite,
        'callId': _currentCallId,
        'media': callType,
        'peerName': _signaling!.connectedDeviceIds.contains(peerDeviceId)
            ? peerName
            : peerName,
        'sdp': offer.sdp,
        'sdpType': offer.type,
      });

      debugPrint('[RTC] Call invite sent to $peerDeviceId');
      return true;
    } catch (e) {
      debugPrint('[RTC] startCall error: $e');
      await _cleanup();
      _callState = AppConstants.callStateIdle;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // === استقبال مكالمة ===
  // ============================================

  Future<void> _handleIncomingCall(SignalingMessage msg) async {
    if (isInCall) {
      // مشغول — نرفض
      await _signaling?.sendTo(msg.from, {
        'type': AppConstants.msgCallBusy,
        'callId': msg.payload['callId'],
      });
      return;
    }

    _currentCallId = msg.payload['callId'] as String;
    _peerDeviceId = msg.from;
    _peerName = msg.payload['peerName'] as String? ?? 'جهاز';
    _callType = msg.payload['media'] as String? ?? AppConstants.callTypeAudio;
    _isCaller = false;
    _callState = AppConstants.callStateRinging;
    _hasRemoteVideo = false;
    notifyListeners();

    // نبّه الواجهة لعرض شاشة المكالمة الواردة
    _eventController.add(RtcEvent(
      type: RtcEventType.incomingCall,
      callId: _currentCallId,
      peerDeviceId: _peerDeviceId,
      peerName: _peerName,
      callType: _callType,
    ));
  }

  /// قبول المكالمة الواردة
  Future<bool> acceptCall() async {
    if (_callState != AppConstants.callStateRinging) return false;

    try {
      _callState = AppConstants.callStateConnecting;
      notifyListeners();

      // 1) فتح الوسائط المحلية
      await _openLocalMedia(_callType);

      // 2) إنشاء الاتصال
      await _createPeerConnection();
      await _addLocalTracks();

      // 3) إرسال إشعار القبول
      await _signaling!.sendTo(_peerDeviceId, {
        'type': AppConstants.msgCallAccept,
        'callId': _currentCallId,
      });

      debugPrint('[RTC] Call accepted');
      return true;
    } catch (e) {
      debugPrint('[RTC] acceptCall error: $e');
      await endCall(reason: 'error');
      return false;
    }
  }

  /// رفض المكالمة
  Future<void> rejectCall({String reason = 'declined'}) async {
    if (_callState != AppConstants.callStateRinging) return;

    await _signaling?.sendTo(_peerDeviceId, {
      'type': AppConstants.msgCallReject,
      'callId': _currentCallId,
      'reason': reason,
    });

    _callState = AppConstants.callStateDeclined;
    notifyListeners();
    await _cleanup();
    _resetState();
  }

  // ============================================
  // === معالجة رسائل Signaling ===
  // ============================================

  Future<void> _onSignalingMessage(SignalingMessage msg) async {
    switch (msg.type) {
      case AppConstants.msgCallInvite:
        await _handleIncomingCall(msg);
        break;

      case AppConstants.msgCallAccept:
        await _handleCallAccept(msg);
        break;

      case AppConstants.msgCallReject:
        await _handleCallReject(msg);
        break;

      case AppConstants.msgCallBusy:
        await _handleCallBusy(msg);
        break;

      case AppConstants.msgCallEnd:
        await _handleRemoteEnd();
        break;

      case AppConstants.msgSdpOffer:
        await _handleSdpOffer(msg);
        break;

      case AppConstants.msgSdpAnswer:
        await _handleSdpAnswer(msg);
        break;

      case AppConstants.msgIceCandidate:
        await _handleRemoteIce(msg);
        break;

      default:
        break;
    }
  }

  Future<void> _handleCallAccept(SignalingMessage msg) async {
    if (_callState != AppConstants.callStateCalling) return;

    _callState = AppConstants.callStateConnecting;
    notifyListeners();
  }

  Future<void> _handleCallReject(SignalingMessage msg) async {
    if (msg.payload['callId'] != _currentCallId) return;

    _callState = AppConstants.callStateDeclined;
    _eventController.add(RtcEvent(
      type: RtcEventType.callEnded,
      callId: _currentCallId,
      peerDeviceId: _peerDeviceId,
      peerName: _peerName,
      callType: _callType,
      reason: 'declined',
    ));
    notifyListeners();

    await _cleanup();
    _resetState();
  }

  Future<void> _handleCallBusy(SignalingMessage msg) async {
    if (msg.payload['callId'] != _currentCallId) return;

    _callState = AppConstants.callStateDeclined;
    _eventController.add(RtcEvent(
      type: RtcEventType.callEnded,
      callId: _currentCallId,
      peerDeviceId: _peerDeviceId,
      peerName: _peerName,
      callType: _callType,
      reason: 'busy',
    ));
    notifyListeners();

    await _cleanup();
    _resetState();
  }

  Future<void> _handleRemoteEnd() async {
    if (_callState == AppConstants.callStateIdle) return;

    _eventController.add(RtcEvent(
      type: RtcEventType.callEnded,
      callId: _currentCallId,
      peerDeviceId: _peerDeviceId,
      peerName: _peerName,
      callType: _callType,
      reason: 'ended',
    ));

    await _cleanup();
    _resetState();
    notifyListeners();
  }

  // ============================================
  // === تبادل SDP/ICE ===
  // ============================================

  Future<void> _handleSdpOffer(SignalingMessage msg) async {
    final callId = msg.payload['callId'] as String?;
    if (callId != _currentCallId || _pc == null) return;

    try {
      final sdp = msg.payload['sdp'] as String;
      final type = msg.payload['sdpType'] as String? ?? 'offer';

      await _pc!.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );

      // معالجة الـ candidates المعلّقة
      await _drainPendingCandidates();

      // إنشاء answer
      final answer = await _pc!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': _callType == AppConstants.callTypeVideo,
      });
      await _pc!.setLocalDescription(answer);

      await _signaling!.sendTo(_peerDeviceId, {
        'type': AppConstants.msgSdpAnswer,
        'callId': _currentCallId,
        'sdp': answer.sdp,
        'sdpType': answer.type,
      });

      debugPrint('[RTC] SDP answer sent');
    } catch (e) {
      debugPrint('[RTC] handleSdpOffer error: $e');
    }
  }

  Future<void> _handleSdpAnswer(SignalingMessage msg) async {
    if (_pc == null) return;
    if (msg.payload['callId'] != _currentCallId) return;

    try {
      final sdp = msg.payload['sdp'] as String;
      final type = msg.payload['sdpType'] as String? ?? 'answer';

      await _pc!.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );

      await _drainPendingCandidates();

      debugPrint('[RTC] SDP answer applied');
    } catch (e) {
      debugPrint('[RTC] handleSdpAnswer error: $e');
    }
  }

  Future<void> _handleRemoteIce(SignalingMessage msg) async {
    final candidateMap = msg.payload['candidate'] as Map<String, dynamic>?;
    if (candidateMap == null) return;

    final candidate = RTCIceCandidate(
      candidateMap['candidate'] as String?,
      candidateMap['sdpMid'] as String?,
      candidateMap['sdpMLineIndex'] as int?,
    );

    if (_pc == null || _pc!.getRemoteDescription() == null) {
      // لم يُفعَّل الـ peer بعد — احفظها مؤقتًا
      _pendingCandidates.add(candidate);
      return;
    }

    try {
      await _pc!.addCandidate(candidate);
    } catch (e) {
      debugPrint('[RTC] addCandidate error: $e');
    }
  }

  Future<void> _drainPendingCandidates() async {
    if (_pc == null) return;
    for (final c in _pendingCandidates) {
      try {
        await _pc!.addCandidate(c);
      } catch (_) {}
    }
    _pendingCandidates.clear();
  }

  // ============================================
  // === إنشاء RTCPeerConnection ===
  // ============================================

  Future<void> _createPeerConnection() async {
    _pc = await createPeerConnection(_iceServers, {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    });

    // --------------------------------------------------------
    // عند وصول ICE candidate محلي → نرسله للطرف الآخر
    // --------------------------------------------------------
    _pc!.onIceCandidate = (candidate) async {
      if (candidate.candidate == null) return;
      await _signaling!.sendTo(_peerDeviceId, {
        'type': AppConstants.msgIceCandidate,
        'callId': _currentCallId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    // --------------------------------------------------------
    // عند وصول مسار بعيد (صوت/فيديو)
    // --------------------------------------------------------
    _pc!.onTrack = (RTCTrackEvent event) {
      debugPrint('[RTC] Remote track: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];

        if (event.track.kind == 'video') {
          _hasRemoteVideo = true;
        }
        notifyListeners();

        _eventController.add(RtcEvent(
          type: RtcEventType.remoteStream,
          callId: _currentCallId,
          peerDeviceId: _peerDeviceId,
          peerName: _peerName,
          callType: _callType,
        ));
      }
    };

    // --------------------------------------------------------
    // تغيّر حالة ICE
    // --------------------------------------------------------
    _pc!.onIceConnectionState = (state) {
      debugPrint('[RTC] ICE state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        endCall(reason: 'ice-failed');
      }
    };

    // --------------------------------------------------------
    // تغيّر حالة الاتصال العامة
    // --------------------------------------------------------
    _pc!.onConnectionState = (state) {
      debugPrint('[RTC] Connection state: $state');
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _callState = AppConstants.callStateConnected;
          _callStartedAt ??= DateTime.now();
          notifyListeners();
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          if (isInCall) {
            endCall(reason: 'disconnected');
          }
          break;
        default:
          break;
      }
    };

    // --------------------------------------------------------
    // عند وصول إعادة تفاوض (نادرة في تطبيقنا)
    // --------------------------------------------------------
    _pc!.onRenegotiationNeeded = () {
      debugPrint('[RTC] Renegotiation needed');
    };
  }

  // ============================================
  // === إدارة الوسائط المحلية ===
  // ============================================

  Future<void> _openLocalMedia(String callType) async {
    final constraints = <String, dynamic>{};

    // الصوت دائمًا
    constraints.addAll(_audioConstraints);

    // الفيديو فقط عند الحاجة
    if (callType == AppConstants.callTypeVideo) {
      constraints.addAll(_videoConstraints);
    }

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);

    // فحص عدد مسارات الفيديو
    if (callType != AppConstants.callTypeVideo) {
      _isVideoEnabled = false;
    }
  }

  Future<void> _addLocalTracks() async {
    if (_localStream == null || _pc == null) return;

    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
  }

  // ============================================
  // === التحكم أثناء المكالمة ===
  // ============================================

  /// كتم/إلغاء كتم الميكروفون
  void toggleMute() {
    if (_localStream == null) return;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = _isMuted;
    }
    _isMuted = !_isMuted;
    notifyListeners();
  }

  /// تشغيل/إيقاف الكاميرا
  Future<void> toggleVideo() async {
    if (_localStream == null) return;

    final videoTracks = _localStream!.getVideoTracks();

    if (videoTracks.isEmpty && !_isVideoEnabled) {
      // إعادة تفعيل الكاميرا
      try {
        final stream = await navigator.mediaDevices.getUserMedia(
          _videoConstraints,
        );
        final newTrack = stream.getVideoTracks().first;
        await _pc?.addTrack(newTrack, _localStream!);

        _isVideoEnabled = true;
      } catch (e) {
        debugPrint('[RTC] re-enable video error: $e');
      }
    } else {
      for (final track in videoTracks) {
        track.enabled = !_isVideoEnabled;
      }
      _isVideoEnabled = !_isVideoEnabled;
    }

    notifyListeners();
  }

  /// تبديل الكاميرا الأمامية/الخلفية
  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;

    try {
      await Helper.switchCamera(videoTracks.first);
      _isFrontCamera = !_isFrontCamera;
      notifyListeners();
    } catch (e) {
      debugPrint('[RTC] switchCamera error: $e');
    }
  }

  /// تشغيل/إيقاف مكبر الصوت
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await Helper.setSpeakerphoneOn(_isSpeakerOn);
    notifyListeners();
  }

  // ============================================
  // === إنهاء المكالمة ===
  // ============================================

  Future<void> endCall({String reason = 'user-hangup'}) async {
    if (!isInCall) return;

    // أخبر الطرف الآخر
    if (_signaling != null && _peerDeviceId.isNotEmpty) {
      try {
        await _signaling!.sendTo(_peerDeviceId, {
          'type': AppConstants.msgCallEnd,
          'callId': _currentCallId,
          'reason': reason,
        });
      } catch (_) {}
    }

    _eventController.add(RtcEvent(
      type: RtcEventType.callEnded,
      callId: _currentCallId,
      peerDeviceId: _peerDeviceId,
      peerName: _peerName,
      callType: _callType,
      reason: reason,
    ));

    await _cleanup();
    _resetState();
    notifyListeners();
  }

  // ============================================
  // === تنظيف الموارد ===
  // ============================================

  Future<void> _cleanup() async {
    // إيقاف المسارات
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        try {
          await track.stop();
        } catch (_) {}
        try {
          _localStream!.removeTrack(track);
        } catch (_) {}
      }
      try {
        await _localStream!.dispose();
      } catch (_) {}
      _localStream = null;
    }

    // إغلاق الاتصال
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;

    _remoteStream = null;
    _pendingCandidates.clear();
    _hasRemoteVideo = false;

    // إعادة حالة مكبر الصوت لطبيعتها
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}
    _isSpeakerOn = false;
  }

  void _resetState() {
    _currentCallId = '';
    _peerDeviceId = '';
    _peerName = '';
    _callType = AppConstants.callTypeAudio;
    _callState = AppConstants.callStateIdle;
    _isCaller = false;
    _callStartedAt = null;
    _isMuted = false;
    _isVideoEnabled = true;
    _isFrontCamera = true;
  }

  // ============================================
  // === أدوات ===
  // ============================================

  String _generateCallId() {
    return 'call_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}';
  }

  String _randomSuffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    final buf = StringBuffer();
    var v = now;
    for (var i = 0; i < 6; i++) {
      buf.write(chars[v % chars.length]);
      v ~/= chars.length;
    }
    return buf.toString();
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _cleanup();
    _eventController.close();
    super.dispose();
  }
}

// ============================================================
// === نماذج الأحداث ===
// ============================================================

enum RtcEventType {
  incomingCall,
  callEnded,
  remoteStream,
  error,
}

class RtcEvent {
  final RtcEventType type;
  final String callId;
  final String peerDeviceId;
  final String peerName;
  final String callType;
  final String? reason;

  RtcEvent({
    required this.type,
    required this.callId,
    required this.peerDeviceId,
    required this.peerName,
    required this.callType,
    this.reason,
  });
}
