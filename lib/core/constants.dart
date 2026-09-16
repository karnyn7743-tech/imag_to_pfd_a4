/// ============================================================
/// الثوابت العامة للتطبيق
/// كل القيم القابلة للتغيير تُجمع هنا لسهولة الصيانة
/// ============================================================

class AppConstants {
  AppConstants._(); // منع الإنشاء

  // ============================================
  // === معلومات التطبيق ===
  // ============================================
  static const String appName = 'LanPhone';
  static const String appVersion = '1.0.0';

  // ============================================
  // === الشبكة المحلية (LAN) ===
  // ============================================
  /// منفذ WebSocket للتحكم (Signaling)
  static const int signalingPort = 5050;

  /// منفذ TCP للرسائل والوسائط
  static const int messagePort = 5051;

  /// منفذ UDP للاكتشاف (Broadcast)
  static const int discoveryPort = 5052;

  /// عنوان البث العام
  static const String broadcastAddress = '255.255.255.255';

  /// عنوان Multicast للاكتشاف
  static const String multicastAddress = '239.255.42.99';

  /// اسم خدمة mDNS
  static const String mdnsServiceType = '_lanphone._tcp';

  /// فترة نبضة التعريف (بالثواني)
  static const int announceIntervalSeconds = 3;

  /// مهلة اعتبار الجهاز غير متصل (بالثواني)
  static const int deviceTimeoutSeconds = 15;

  /// مهلة الاتصال بالجهاز (بالثواني)
  static const int connectionTimeoutSeconds = 10;

  /// فترة Keep-alive للـ WebSocket (بالثواني)
  static const int keepAliveSeconds = 15;

  // ============================================
  // === WebRTC (الصوت والفيديو) ===
  // ============================================
  /// سرعة Opus بالبايت/ثانية (16 kbps = نبرة قريبة من GSM)
  static const int opusBitrate = 16000;

  /// معدل أخذ العينات الصوتي
  static const int audioSampleRate = 8000; // 8 kHz مثل GSM

  /// عدد القنوات الصوتية (1 = مونو)
  static const int audioChannels = 1;

  /// مدة الحزمة الصوتية (ms)
  static const int audioPacketTime = 20;

  /// دقة الفيديو الافتراضية
  static const int videoWidth = 640;
  static const int videoHeight = 480;
  static const int videoFps = 20;

  /// حجم مخزن التقطع (jitter buffer) بالمللي ثانية
  static const int jitterBufferMs = 50;

  // ============================================
  // === بروتوكول الرسائل ===
  // ============================================
  /// حجم القطعة عند إرسال ملف كبير (بايت)
  static const int fileChunkSize = 64 * 1024; // 64 KB

  /// الحد الأقصى لحجم الرسالة النصية
  static const int maxTextMessageLength = 10000;

  /// الحد الأقصى لحجم الملف المسموح
  static const int maxFileSize = 100 * 1024 * 1024; // 100 MB

  // ============================================
  // === قاعدة البيانات ===
  // ============================================
  static const String databaseName = 'lan_phone.db';
  static const int databaseVersion = 1;

  // ============================================
  // === المفاتيح (SharedPreferences) ===
  // ============================================
  static const String keyDeviceId = 'device_id';
  static const String keyDeviceName = 'device_name';
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
  // === المسارات (Routes) ===
  // ============================================
  static const String routeSplash = '/';
  static const String routeHome = '/home';
  static const String routeChat = '/chat';
  static const String routeAudioCall = '/audio-call';
  static const String routeVideoCall = '/video-call';
  static const String routeSettings = '/settings';
  static const String routeQrScan = '/qr-scan';
}
