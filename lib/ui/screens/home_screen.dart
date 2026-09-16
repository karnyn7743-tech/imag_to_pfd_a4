import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/discovery/device_discovery.dart';
import '../../core/services/permission_service.dart';
import '../theme/app_theme.dart';
import 'tabs/conversations_tab.dart';
import 'tabs/devices_tab.dart';
import 'tabs/calls_tab.dart';

/// ============================================================
/// الشاشة الرئيسية
/// 3 تبويبات: المحادثات، المكالمات، الأجهزة
/// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // ============================================
  // === الحالة ===
  // ============================================
  late TabController _tabController;
  bool _permissionsChecked = false;

  // ============================================
  // === دورة الحياة ===
  // ============================================

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    // طلب أذونات الاكتشاف والإشعارات بعد ظهور الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureDiscoveryPermissions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================================
  // === الأذونات ===
  // ============================================

  Future<void> _ensureDiscoveryPermissions() async {
    if (_permissionsChecked) return;
    _permissionsChecked = true;

    final ok = await PermissionService.requestDiscovery();

    if (!ok && mounted) {
      // المستخدم رفض — نُظهر تحذيرًا
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'بدون إذن الموقع والواي فاي، لن يعمل اكتشاف الأجهزة',
          ),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'الإعدادات',
            textColor: Colors.white,
            onPressed: () {
              PermissionService.openAppSettings();
            },
          ),
        ),
      );
    }
  }

  // ============================================
  // === الأزرار العلوية ===
  // ============================================

  void _openQrScanner() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ماسح QR سيُضاف في إصدار لاحق'),
      ),
    );
  }

  void _openSettings() {
    // سنجعلها تنتقل لتبويب الأجهزة كمكان افتراضي
    // أو نُنشئ شاشة إعدادات لاحقًا
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('شاشة الإعدادات ستُضاف في إصدار لاحق'),
      ),
    );
  }

  // ============================================
  // === FAB ===
  // ============================================

  void _onFabPressed() {
    // انتقل لتبويب الأجهزة لبدء محادثة جديدة
    _tabController.animateTo(2);
  }

  // ============================================
  // === الواجهة ===
  // ============================================

  @override
  Widget build(BuildContext context) {
    final discovery = context.watch<DeviceDiscovery>();
    final onlineCount = discovery.onlineDevices.length;

    // عدد المحادثات غير المقروءة
    // (نعرضه ديناميكيًا عبر Consumer لتحديثه مع أي تغيير)
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            // ==========================================
            // === تبويب المحادثات ===
            // ==========================================
            const Tab(
              child: _TabContent(
                icon: Icons.chat_bubble_outline,
                label: 'المحادثات',
              ),
            ),

            // ==========================================
            // === تبويب المكالمات ===
            // ==========================================
            const Tab(
              child: _TabContent(
                icon: Icons.call_outlined,
                label: 'المكالمات',
              ),
            ),

            // ==========================================
            // === تبويب الأجهزة (مع شارة العدد) ===
            // ==========================================
            Tab(
              child: _TabContent(
                icon: Icons.devices_outlined,
                label: 'الأجهزة',
                badge: onlineCount > 0 ? onlineCount : null,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'اقتران بـ QR',
            onPressed: _openQrScanner,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'الإعدادات',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ConversationsTab(),
          CallsTab(),
          DevicesTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          // نُخفي الـ FAB في تبويب المكالمات
          final showFab = _tabController.index != 1;
          return AnimatedScale(
            scale: showFab ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: FloatingActionButton(
              onPressed: _onFabPressed,
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              tooltip: 'محادثة جديدة',
              child: const Icon(Icons.edit_outlined),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// === محتوى التبويب (أيقونة + نص + شارة اختيارية) ===
// ============================================================
class _TabContent extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? badge;

  const _TabContent({
    required this.icon,
    required this.label,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label),
        if (badge != null && badge! > 0) ...[
          const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: AppTheme.errorColor,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Text(
              badge! > 99 ? '99+' : badge.toString(),
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
