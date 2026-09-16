/// ============================================================
/// نموذج الجهاز المكتشف على الشبكة
/// ============================================================
class DiscoveredDevice {
  final String deviceId;
  final String name;
  final String ip;
  final int port;
  final List<String> capabilities;
  final DateTime lastSeen;
  final bool isOnline;

  const DiscoveredDevice({
    required this.deviceId,
    required this.name,
    required this.ip,
    required this.port,
    required this.capabilities,
    required this.lastSeen,
    required this.isOnline,
  });

  DiscoveredDevice copyWith({
    String? deviceId,
    String? name,
    String? ip,
    int? port,
    List<String>? capabilities,
    DateTime? lastSeen,
    bool? isOnline,
  }) {
    return DiscoveredDevice(
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      capabilities: capabilities ?? this.capabilities,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  /// هل يدعم هذا الجهاز مكالمات الفيديو؟
  bool get supportsVideo => capabilities.contains('video');

  /// هل يدعم المكالمات الصوتية؟
  bool get supportsVoice => capabilities.contains('voice');

  @override
  String toString() =>
      'DiscoveredDevice($name, $ip:$port, online=$isOnline)';
}
