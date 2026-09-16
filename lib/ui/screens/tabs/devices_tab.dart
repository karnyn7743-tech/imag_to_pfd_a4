import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:provider/provider.dart';

import '../../../core/discovery/device_discovery.dart';
import '../../../core/discovery/discovered_device.dart';
import '../../../core/services/permission_service.dart';
import '../../theme/app_theme.dart';
import '../chat_screen.dart';

/// ============================================================
/// تبويب الأجهزة المتصلة على الشبكة المحلية
/// ============================================================
class DevicesTab extends StatelessWidget {
  const DevicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceDiscovery>(
      builder: (context, discovery, _) {
        final allDevices = discovery.devices;
        final onlineDevices = discovery.onlineDevices;
        final offlineDevices = allDevices
            .where((d) => !d.isOnline)
            .toList();

        if (!discovery.isRunning) {
          return const _LoadingState(
            message: 'جارٍ تشغيل خدمة الاكتشاف...',
          );
        }

        if (allDevices.isEmpty) {
          return _EmptyDevicesState(
            onRefresh: () {
              discovery.refreshNow();
            },
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            discovery.refreshNow();
            await Future.delayed(const Duration(milliseconds: 800));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // ============================================
              // === ملخص الحالة ===
              // ============================================
              _StatusBar(
                online: onlineDevices.length,
                total: allDevices.length,
                localIp: discovery.localIp,
              ),

              // ============================================
              // === الأجهزة المتصلة ===
              // ============================================
              if (onlineDevices.isNotEmpty) ...[
                const _SectionHeader(title: 'الأجهزة المتصلة'),
                ...onlineDevices.map(
                  (d) => _DeviceTile(device: d, isOnline: true),
                ),
              ],

              // ============================================
              // === الأجهزة غير المتصلة ===
              // ============================================
              if (offlineDevices.isNotEmpty) ...[
                const _SectionHeader(title: 'الأجهزة السابقة'),
                ...offlineDevices.map(
                  (d) => _DeviceTile(device: d, isOnline: false),
                ),
              ],

              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// === شريط الحالة ===
// ============================================================
class _StatusBar extends StatelessWidget {
  final int online;
  final int total;
  final String localIp;

  const _StatusBar({
    required this.online,
    required this.total,
    required this.localIp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTheme.primaryColor.withOpacity(0.25),
                  AppTheme.primaryColor.withOpacity(0.08),
                ]
              : [
                  AppTheme.primaryColor.withOpacity(0.12),
                  AppTheme.primaryColor.withOpacity(0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_tethering,
              color: AppTheme.primaryColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  online == 0
                      ? 'لا توجد أجهزة متصلة'
                      : '$online ${online == 1 ? "جهاز متصل" : "أجهزة متصلة"}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  localIp.isEmpty
                      ? 'جارٍ اكتشاف الشبكة...'
                      : 'IP الجهاز: $localIp',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// === رأس قسم ===
// ============================================================
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
        ),
      ),
    );
  }
}

// ============================================================
// === صف جهاز ===
// ============================================================
class _DeviceTile extends StatelessWidget {
  final DiscoveredDevice device;
  final bool isOnline;

  const _DeviceTile({
    required this.device,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOnline ? () => _openChat(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? AppTheme.darkDivider
                    : AppTheme.lightDivider,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // ============================================
                // === الأفاتار ===
                // ============================================
                _DeviceAvatar(
                  name: device.name,
                  isOnline: isOnline,
                ),

                const SizedBox(width: 14),

                // ============================================
                // === الاسم والمعلومات ===
                // ============================================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        device.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.wifi,
                            size: 12,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isOnline
                                  ? device.ip
                                  : 'آخر ظهور ${_formatLastSeen(device.lastSeen)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.lightTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ============================================
                // === الأزرار السريعة ===
                // ============================================
                if (isOnline) ...[
                  _IconActionButton(
                    icon: Icons.call_outlined,
                    tooltip: 'مكالمة صوتية',
                    color: AppTheme.successColor,
                    onTap: () => _callFromTile(context, isVideo: false),
                  ),
                  const SizedBox(width: 6),
                  _IconActionButton(
                    icon: Icons.videocam_outlined,
                    tooltip: 'مكالمة فيديو',
                    color: AppTheme.primaryColor,
                    onTap: () => _callFromTile(context, isVideo: true),
                  ),
                  const SizedBox(width: 4),
                ],

                Icon(
                  Icons.chevron_left,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // === فتح محادثة ===
  // ============================================
  void _openChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(peer: device),
      ),
    );
  }

  // ============================================
  // === بدء مكالمة من الزر السريع ===
  // ============================================
  Future<void> _callFromTile(
    BuildContext context, {
    required bool isVideo,
  }) async {
    // ✅ استخدام ph.Permission بدل Permission
    final permissions = isVideo
        ? <ph.Permission>[
            ph.Permission.microphone,
            ph.Permission.camera,
          ]
        : <ph.Permission>[ph.Permission.microphone];

    final granted = await PermissionService.requestAll(permissions);
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('نحتاج الأذونات لبدء المكالمة'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // افتح المحادثة ثم ابدأ المكالمة (أبسط تدفق)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(peer: device),
      ),
    );
  }

  String _formatLastSeen(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'قبل لحظات';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} س';
    return 'قبل ${diff.inDays} ي';
  }
}

// ============================================================
// === الأفاتار ===
// ============================================================
class _DeviceAvatar extends StatelessWidget {
  final String name;
  final bool isOnline;

  const _DeviceAvatar({
    required this.name,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isOnline
                  ? [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.75),
                    ]
                  : [
                      Colors.grey.shade500,
                      Colors.grey.shade700,
                    ],
            ),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isOnline ? AppTheme.successColor : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// === زر أيقونة صغير ===
// ============================================================
class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.15),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// === حالة فارغة (لا توجد أجهزة) ===
// ============================================================
class _EmptyDevicesState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyDevicesState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_tethering,
                size: 52,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد أجهزة على الشبكة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تأكد من أن الأجهزة الأخرى:\n'
              '• مفتوحة على نفس التطبيق\n'
              '• متصلة بنفس شبكة الواي فاي',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textColor, height: 1.6),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة البحث'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// === حالة التحميل ===
// ============================================================
class _LoadingState extends StatelessWidget {
  final String message;

  const _LoadingState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}
