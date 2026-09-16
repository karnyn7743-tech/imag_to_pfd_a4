import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../theme/app_theme.dart';

/// ============================================================
/// الشاشة الرئيسية
/// تعرض 3 تبويبات: المحادثات، المكالمات، الأجهزة
/// (سيتم ربطها بالبيانات الحقيقية لاحقًا)
/// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'المحادثات', icon: Icon(Icons.chat_bubble_outline)),
            Tab(text: 'المكالمات', icon: Icon(Icons.call_outlined)),
            Tab(text: 'الأجهزة', icon: Icon(Icons.devices_outlined)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'اقتران بـ QR',
            onPressed: () {
              // سنربطها لاحقًا
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'الإعدادات',
            onPressed: () {
              // سنربطها لاحقًا
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ConversationsTab(),
          _CallsTab(),
          _DevicesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // سنربطها لاحقًا ببدء محادثة جديدة
        },
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

// ============================================================
// === تبويب المحادثات ===
// ============================================================
class _ConversationsTab extends StatelessWidget {
  const _ConversationsTab();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'لا توجد محادثات بعد',
      subtitle: 'ابدأ محادثة جديدة مع جهاز على نفس الشبكة',
    );
  }
}

// ============================================================
// === تبويب المكالمات ===
// ============================================================
class _CallsTab extends StatelessWidget {
  const _CallsTab();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.call_outlined,
      title: 'لا توجد مكالمات',
      subtitle: 'سجل المكالمات الصوتية والمرئية سيظهر هنا',
    );
  }
}

// ============================================================
// === تبويب الأجهزة ===
// ============================================================
class _DevicesTab extends StatelessWidget {
  const _DevicesTab();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.wifi_tethering,
      title: 'جارٍ البحث عن أجهزة...',
      subtitle: 'تأكد من اتصال الجهازين بنفس شبكة الواي فاي',
    );
  }
}

// ============================================================
// === شاشة فارغة موحّدة ===
// ============================================================
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
