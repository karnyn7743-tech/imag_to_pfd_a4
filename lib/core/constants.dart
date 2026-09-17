/// ============================================================
/// الثوابت العامة للتطبيق
/// ============================================================

class AppConstants {
  AppConstants._();

  // ============================================
  // === معلومات التطبيق ===
  // ============================================
  static const String appName = 'LanPhone';
  static const String appVersion = '1.0.0';

  // ============================================
  // === الشبكة المحلية (LAN) ===
  // ============================================
  static const int signalingPort = 5050;
  static const int messagePort = 5051;
  static const int discoveryPort = 5052;

  static const String broadcastAddress = '255.255.255.255';
  static const String multicastAddress = '239.255.42.99';
  static const String mdnsServiceType = '_lanphone._tcp';

  static const int announceIntervalSeconds = 3;
  static const int deviceTimeoutSeconds = 15;
  static const int connectionTimeoutSeconds = 10;
  static const int keepAliveSeconds = 15;

  // ============================================
  // === رقم الاتصال (مثل رقم SIM) ===
  // ============================================
  /// الحد الأدنى للرقم (1000 = 4 أرقام)
  static const int numberMin = 1000;

  /// الحد الأقصى للرقم (9999 = 4 أرقام)
  static const int numberMax = 9999;

  /// عدد محاولات توليد رقم غير متعارض
  static const int numberGenerationRetries = 20;

  // ============================================
  // === WebRTC ===
  // ============================================
  static const int opusBitrate = 16000;
  static const int audioSampleRate = 8000;
  static const int audioChannels = 1;
  static const int audioPacketTime = 20;

  static const int videoWidth = 640;
  static const int videoHeight = 480;
  static const int videoFps = 20;

  static const int jitterBufferMs = 50;

  // ============================================
  // === الرسائل ===
  // ============================================
  static const int fileChunkSize = 64 * 1024;
  static const int maxTextMessageLength = 10000;
  static const int maxFileSize = 100 * 1024 * 1024;

  // ============================================
  // === قاعدة البيانات ===
  // ============================================
  static const String databaseName = 'lan_phone.db';
  static const int databaseVersion = 2; // ← رُفع من 1 إلى 2

  // ============================================
  // === المفاتيح (SharedPreferences) ===
  // ============================================
  static const String keyDeviceId = 'device_id';
  static const String keyDeviceName = 'device_name';
  static const String keyDeviceNumber = 'device_number'; // ← جديد
  static const String keyThemeMode = 'theme_mode';
  static const String keyRingtone = 'ringtone';
  static const String keyVibration = 'vibration';

  // ============================================
  // === أنواع الرسائل (Signaling) ===
  // ============================================
  static const String msgAnnounce = 'ANNOUNCE';
  static const String msgBye = 'BYE';

  static const String msgCallInvite = 'CALL_INVITE';
  static const String msgCallAccept = 'CALL_ACCEPT';
  static const String msgCallReject = 'CALL_REJECT';
  static const String msgCallEnd = 'CALL_END';
  static const String msgCallBusy = 'CALL_BUSY';

  static const String msgIceCandidate = 'ICE';
  static const String msgSdpOffer = 'SDP_OFFER';
  static const String msgSdpAnswer = 'SDP_ANSWER';

  static const String msgTextMessage = 'MSG';
  static const String msgMessageAck = 'MSG_ACK';
  static const String msgTyping = 'TYPING';

  static const String msgPing = 'PING';
  static const String msgPong = 'PONG';

  // ============================================
  // === أنواع الوسائط ===
  // ============================================
  static const String mediaText = 'text';
  static const String mediaImage = 'image';
  static const String mediaVideo = 'video';
  static const String mediaAudio = 'audio';
  static const String mediaFile = 'file';

  // ============================================
  // === حالات المكالمة ===
  // ============================================
  static const String callStateIdle = 'idle';
  static const String callStateCalling = 'calling';
  static const String callStateRinging = 'ringing';
  static const String callStateConnecting = 'connecting';
  static const String callStateConnected = 'connected';
  static const String callStateEnded = 'ended';
  static const String callStateMissed = 'missed';
  static const String callStateDeclined = 'declined';

  // ============================================
  // === أنواع المكالمة ===
  // ============================================
  static const String callTypeAudio = 'audio';
  static const String callTypeVideo = 'video';

  // ============================================
  // === اتجاهات المكالمة (للسجل) ===
  // ============================================
  static const String callDirectionIncoming = 'incoming';
  static const String callDirectionOutgoing = 'outgoing';

  // ============================================
  // === المسارات ===
  // ============================================
  static const String routeSplash = '/';
  static const String routeHome = '/home';
  static const String routeChat = '/chat';
  static const String routeAudioCall = '/audio-call';
  static const String routeVideoCall = '/video-call';
  static const String routeSettings = '/settings';
  static const String routeQrScan = '/qr-scan';
  static const String routeDialer = '/dialer'; // ← جديد
}
