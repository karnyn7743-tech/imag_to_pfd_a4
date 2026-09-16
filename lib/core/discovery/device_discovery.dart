import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/database_helper.dart';
import '../constants.dart';
import 'discovered_device.dart';

/// ============================================================
/// خدمة اكتشاف الأجهزة على الشبكة المحلية
/// تعتمد على:
///   1) UDP Broadcast (الأساسية والموثوقة)
///   2) mDNS (كآلية ثانوية)
/// ============================================================
class DeviceDiscovery extends ChangeNotifier {
  DeviceDiscovery();

  // ============================================
  // === الحالة الداخلية ===
  // ============================================

  /// معرّف هذا الجهاز (يُنشأ أول مرة فقط ويُخزَّن)
  String _deviceId = '';
  String get deviceId => _deviceId;

  /// اسم هذا الجهاز (يظهر للآخرين)
  String _deviceName = '';
  String get deviceName => _deviceName;

  /// IP هذا الجهاز على الشبكة المحلية
  String _localIp = '';
  String get localIp => _localIp;

  /// هل الخدمة تعمل الآن؟
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// خريطة الأجهزة المكتشفة (deviceId → DiscoveredDevice)
  final Map<String, DiscoveredDevice> _devices = {};
  List<DiscoveredDevice> get devices => _devices.values.toList();

  /// قائمة الأجهزة المتصلة فقط (آخر نبضة خلال المهلة)
  List<DiscoveredDevice> get onlineDevices => _devices.values
      .where((d) => d.isOnline)
      .toList();

  // ============================================
  // === الـ Sockets والـ Timers ===
  // ============================================
  RawDatagramSocket? _udpSocket;
  Timer? _announceTimer;
  Timer? _cleanupTimer;
  Timer? _presenceTimer;

  MDnsClient? _mdnsClient;
  StreamSubscription<PtrResourceRecord>? _mdnsSubscription;

  // ============================================
  // === دورة حياة الخدمة ===
  // ============================================

  /// بدء الاكتشاف
  Future<void> start() async {
    if (_isRunning) return;

    try {
      // 1) تحميل/إنشاء هوية هذا الجهاز
      await _loadOrCreateIdentity();

      // 2) اكتشاف IP المحلي
      _localIp = await _detectLocalIp();
      debugPrint('[Discovery] Local IP: $_localIp');

      // 3) فتح UDP Socket
      await _openUdpSocket();

      // 4) بدء mDNS
      _startMdns();

      // 5) تحميل الأجهزة المخزنة من قاعدة البيانات
      await _loadStoredDevices();

      // 6) إرسال أول نبضة تعريف فورًا
      _sendAnnounce();

      // 7) تشغيل المؤقتات
      _announceTimer = Timer.periodic(
        const Duration(seconds: AppConstants.announceIntervalSeconds),
        (_) => _sendAnnounce(),
      );

      _cleanupTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _cleanupStaleDevices(),
      );

      // نبضة أسرع في البداية لتسريع الاكتشاف
      _presenceTimer = Timer.periodic(
        const Duration(seconds: 2),
        (t) {
          _sendAnnounce();
        },
      );
      // إيقاف النبض السريع بعد 30 ثانية
      Future.delayed(const Duration(seconds: 30), () {
        _presenceTimer?.cancel();
        _presenceTimer = null;
      });

      _isRunning = true;
      notifyListeners();

      debugPrint('[Discovery] Service started. DeviceId=$_deviceId');
    } catch (e) {
      debugPrint('[Discovery] Failed to start: $e');
    }
  }

  /// إيقاف الاكتشاف
  Future<void> stop() async {
    _announceTimer?.cancel();
    _cleanupTimer?.cancel();
    _presenceTimer?.cancel();
    _announceTimer = null;
    _cleanupTimer = null;
    _presenceTimer = null;

    await _mdnsSubscription?.cancel();
    _mdnsSubscription = null;
    _mdnsClient?.stop();
    _mdnsClient = null;

    // إرسال رسالة وداع قبل الإغلاق
    try {
      _sendBye();
    } catch (_) {}

    _udpSocket?.close();
    _udpSocket = null;

    _isRunning = false;
    notifyListeners();

    debugPrint('[Discovery] Service stopped');
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  // ============================================
  // === الهوية (Identity) ===
  // ============================================

  Future<void> _loadOrCreateIdentity() async {
    final prefs = await SharedPreferences.getInstance();

    // معرّف الجهاز
    var id = prefs.getString(AppConstants.keyDeviceId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(AppConstants.keyDeviceId, id);
    }
    _deviceId = id;

    // اسم الجهاز
    var name = prefs.getString(AppConstants.keyDeviceName);
    if (name == null || name.isEmpty) {
      // اسم افتراضي: LanPhone-XXXX (آخر 4 أحرف من المعرّف)
      name = 'LanPhone-${_deviceId.substring(0, 4).toUpperCase()}';
      await prefs.setString(AppConstants.keyDeviceName, name);
    }
    _deviceName = name;
  }

  /// تحديث اسم الجهاز (من الإعدادات)
  Future<void> updateDeviceName(String newName) async {
    if (newName.trim().isEmpty) return;
    _deviceName = newName.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyDeviceName, _deviceName);
    _sendAnnounce();
    notifyListeners();
  }

  // ============================================
  // === كشف IP المحلي ===
  // ============================================

  Future<String> _detectLocalIp() async {
    try {
      // الطريقة الأكثر موثوقية: فتح اتصال وهمي واكتشاف العنوان المستخدم
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // نبحث عن واجهة WiFi أولًا
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('wlan') ||
            name.contains('wifi') ||
            name.contains('en0')) {
          for (final addr in iface.addresses) {
            if (_isPrivateIp(addr.address)) return addr.address;
          }
        }
      }

      // إن لم نجد، نأخذ أول عنوان خاص
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (_isPrivateIp(addr.address)) return addr.address;
        }
      }

      return '127.0.0.1';
    } catch (e) {
      debugPrint('[Discovery] detectLocalIp error: $e');
      return '127.0.0.1';
    }
  }

  bool _isPrivateIp(String ip) {
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('10.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]) ?? 0;
        if (second >= 16 && second <= 31) return true;
      }
    }
    return false;
  }

  // ============================================
  // === UDP Socket ===
  // ============================================

  Future<void> _openUdpSocket() async {
    _udpSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      AppConstants.discoveryPort,
      reuseAddress: true,
      reusePort: false,
    );

    _udpSocket!.broadcastEnabled = true;
    _udpSocket!.multicastHops = 1;

    _udpSocket!.listen(
      _onUdpEvent,
      onError: (e) => debugPrint('[Discovery] UDP error: $e'),
      onDone: () => debugPrint('[Discovery] UDP closed'),
    );
  }

  void _onUdpEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final datagram = _udpSocket?.receive();
    if (datagram == null) return;

    try {
      final text = utf8.decode(datagram.data);
      final data = jsonDecode(text) as Map<String, dynamic>;
      _handleIncoming(data, datagram.address.address);
    } catch (e) {
      // حزمة غير صالحة — نتجاهلها
    }
  }

  // ============================================
  // === إرسال النبضات ===
  // ============================================

  void _sendAnnounce() {
    _broadcast({
      'type': AppConstants.msgAnnounce,
      'deviceId': _deviceId,
      'name': _deviceName,
      'ip': _localIp,
      'port': AppConstants.signalingPort,
      'messagePort': AppConstants.messagePort,
      'capabilities': ['text', 'voice', 'video', 'media'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _sendBye() {
    _broadcast({
      'type': AppConstants.msgBye,
      'deviceId': _deviceId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _broadcast(Map<String, dynamic> payload) {
    if (_udpSocket == null) return;

    try {
      final data = utf8.encode(jsonEncode(payload));

      // بث على العنوان العام
      _udpSocket!.send(
        data,
        InternetAddress(AppConstants.broadcastAddress),
        AppConstants.discoveryPort,
      );

      // بث على العنوان المتعدد (بعض الشبكات تحجب الأول)
      _udpSocket!.send(
        data,
        InternetAddress(AppConstants.multicastAddress),
        AppConstants.discoveryPort,
      );
    } catch (e) {
      debugPrint('[Discovery] broadcast error: $e');
    }
  }

  // ============================================
  // === استقبال النبضات ===
  // ============================================

  Future<void> _handleIncoming(
    Map<String, dynamic> data,
    String sourceIp,
  ) async {
    final type = data['type'] as String?;
    final deviceId = data['deviceId'] as String?;
    if (deviceId == null) return;

    // تجاهل نبضاتنا نحن
    if (deviceId == _deviceId) return;

    switch (type) {
      case AppConstants.msgAnnounce:
        await _handleAnnounce(data, sourceIp);
        break;
      case AppConstants.msgBye:
        await _handleBye(deviceId);
        break;
      default:
        break;
    }
  }

  Future<void> _handleAnnounce(
    Map<String, dynamic> data,
    String sourceIp,
  ) async {
    final deviceId = data['deviceId'] as String;
    final name = (data['name'] as String?) ?? 'جهاز غير معروف';

    // نستخدم IP الحقيقي من الحزمة (أدق من المُعلن)
    final ip = sourceIp;
    final port = (data['port'] as int?) ?? AppConstants.signalingPort;
    final caps = (data['capabilities'] as List?)?.cast<String>() ?? const [];

    final isNew = !_devices.containsKey(deviceId);

    final device = DiscoveredDevice(
      deviceId: deviceId,
      name: name,
      ip: ip,
      port: port,
      capabilities: caps,
      lastSeen: DateTime.now(),
      isOnline: true,
    );

    _devices[deviceId] = device;

    // حفظ في قاعدة البيانات
    await DatabaseHelper.instance.upsertDevice({
      'device_id': deviceId,
      'name': name,
      'ip_address': ip,
      'port': port,
      'capabilities': jsonEncode(caps),
      'last_seen': DateTime.now().millisecondsSinceEpoch,
      'is_favorite': 0,
      'is_blocked': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    if (isNew) {
      debugPrint('[Discovery] New device: $name @ $ip');
    }

    notifyListeners();
  }

  Future<void> _handleBye(String deviceId) async {
    if (_devices.containsKey(deviceId)) {
      _devices[deviceId] = _devices[deviceId]!.copyWith(isOnline: false);
      notifyListeners();
      debugPrint('[Discovery] Device said bye: $deviceId');
    }
  }

  // ============================================
  // === تنظيف الأجهزة المنقطعة ===
  // ============================================

  void _cleanupStaleDevices() {
    final now = DateTime.now();
    bool changed = false;

    for (final entry in _devices.entries.toList()) {
      final d = entry.value;
      final diff = now.difference(d.lastSeen).inSeconds;

      if (d.isOnline && diff > AppConstants.deviceTimeoutSeconds) {
        _devices[entry.key] = d.copyWith(isOnline: false);
        changed = true;
        debugPrint('[Discovery] Device offline: ${d.name}');
      }
    }

    if (changed) notifyListeners();
  }

  // ============================================
  // === تحميل الأجهزة المخزّنة ===
  // ============================================

  Future<void> _loadStoredDevices() async {
    try {
      final rows = await DatabaseHelper.instance.getAllDevices();
      for (final row in rows) {
        final id = row['device_id'] as String;
        // لا نُحمّل جهازنا
        if (id == _deviceId) continue;

        _devices[id] = DiscoveredDevice(
          deviceId: id,
          name: row['name'] as String,
          ip: row['ip_address'] as String,
          port: row['port'] as int,
          capabilities: _parseCaps(row['capabilities']),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(
            row['last_seen'] as int,
          ),
          isOnline: false, // ننتظر نبضة للتأكيد
        );
      }
      debugPrint('[Discovery] Loaded ${_devices.length} stored devices');
      notifyListeners();
    } catch (e) {
      debugPrint('[Discovery] loadStoredDevices error: $e');
    }
  }

  List<String> _parseCaps(dynamic raw) {
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw as String) as List;
      return decoded.cast<String>();
    } catch (_) {
      return const [];
    }
  }

  // ============================================
  // === mDNS ===
  // ============================================

  void _startMdns() {
    try {
      _mdnsClient = MDnsClient();
      _mdnsClient!.start().then((_) {
        _mdnsSubscription = _mdnsClient!
            .lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer(AppConstants.mdnsServiceType),
            )
            .listen((ptr) async {
          debugPrint('[Discovery] mDNS found: ${ptr.domainName}');
          await _resolveMdnsService(ptr.domainName);
        });
      });
    } catch (e) {
      debugPrint('[Discovery] mDNS start error: $e');
    }
  }

  Future<void> _resolveMdnsService(String serviceName) async {
    try {
      await for (final srv in _mdnsClient!.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(serviceName),
      )) {
        await for (final txt in _mdnsClient!.lookup<TxtResourceRecord>(
          ResourceRecordQuery.text(serviceName),
        )) {
          // نحاول استخراج deviceId من TXT
          final txtParts = txt.text.split(',');
          String? deviceId;
          for (final part in txtParts) {
            if (part.startsWith('id=')) deviceId = part.substring(3);
          }
          if (deviceId == null || deviceId == _deviceId) return;

          // mDNS وحده لا يكفي — سننتظر نبضة UDP لتأكيد الاتصال
          debugPrint('[Discovery] mDNS resolved: $deviceId @ ${srv.target}:${srv.port}');
        }
      }
    } catch (e) {
      debugPrint('[Discovery] resolveMdns error: $e');
    }
  }

  // ============================================
  // === واجهات عامة للاستعلام ===
  // ============================================

  DiscoveredDevice? getDevice(String deviceId) => _devices[deviceId];

  bool isDeviceOnline(String deviceId) {
    final d = _devices[deviceId];
    return d != null && d.isOnline;
  }

  /// إرسال نبضة فورية (للاستخدام عند فتح شاشة الأجهزة)
  void refreshNow() {
    _sendAnnounce();
  }

  /// حذف جهاز يدويًا
  Future<void> removeDevice(String deviceId) async {
    _devices.remove(deviceId);
    await DatabaseHelper.instance.deleteDevice(deviceId);
    notifyListeners();
  }
}
