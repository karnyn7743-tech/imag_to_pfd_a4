import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/discovery/device_discovery.dart';
import '../../data/database/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/permission_dialog.dart';

/// ============================================================
/// شاشة الإعدادات
/// ============================================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ============================================
  // === الحالة ===
  // ============================================
  bool _isLoading = true;

  // الإعدادات
  String _deviceName = '';
  String _deviceId = '';
  String _localIp = '';
  String _themeMode = 'system';
  bool _vibrationEnabled = true;
  bool _soundEnabled = true;

  // ============================================
  // === دورة الحياة ===
  // ============================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final discovery = context.read<DeviceDiscovery>();

      if (!mounted) return;
      setState(() {
        _deviceName = discovery.deviceName;
        _deviceId = discovery.deviceId;
        _localIp = discovery.localIp;
        _themeMode = prefs.getString(AppConstants.keyThemeMode) ?? 'system';
        _vibrationEnabled = prefs.getBool(AppConstants.keyVibration) ?? true;
        _soundEnabled = prefs.getBool(AppConstants.keyRingtone) ?? true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[Settings] loadSettings error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ============================================
  // === تعديل اسم الجهاز ===
  // ============================================

  Future<void> _editDeviceName() async {
    final controller = TextEditingController(text: _deviceName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اسم الجهاز'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(
            hintText: 'مثال: هاتف أحمد',
            prefixIcon: Icon(Icons.devices_outlined),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    // حرّر وحدة التحكم بعد إغلاق الحوار
    controller.dispose();

    if (newName == null || newName.isEmpty || newName == _deviceName) {
      return;
    }

    final discovery = context.read<DeviceDiscovery>();
    await discovery.updateDeviceName(newName);

    if (!mounted) return;
    setState(() => _deviceName = newName);

    _showSnack('تم تحديث اسم الجهاز', isSuccess: true);
  }

  // ============================================
  // === المظهر ===
  // ============================================

  Future<void> _setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyThemeMode, mode);
    if (!mounted) return;
    setState(() => _themeMode = mode);
    _showSnack('سيُطبَّق المظهر عند إعادة فتح التطبيق');
  }

  // ============================================
  // === الرنين والاهتزاز ===
  // ============================================

  Future<void> _toggleVibration(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyVibration, value);
    if (!mounted) return;
    setState(() => _vibrationEnabled = value);
  }

  Future<void> _toggleSound(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyRingtone, value);
    if (!mounted) return;
    setState(() => _soundEnabled = value);
  }

  // ============================================
  // === الإشعارات ===
  // ============================================

  Future<void> _manageNotifications() async {
    final granted = await PermissionDialog.ensure(
      context,
      permissions: <ph.Permission>[ph.Permission.notification],
      title: 'الإشعارات',
      message: 'نحتاج الإذن لعرض إشعارات المكالمات والرسائل',
      icon: Icons.notifications_outlined,
    );

    if (!mounted) return;
    if (granted) {
      _showSnack('الإشعارات مفعّلة', isSuccess: true);
    }
  }

  // ============================================
  // === معلومات الشبكة ===
  // ============================================

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showSnack('تم نسخ $label');
  }

  // ============================================
  // === إدارة التخزين ===
  // ============================================

  Future<void> _clearAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          size: 40,
          color: AppTheme.errorColor,
        ),
        title: const Text('إعادة تعيين التطبيق'),
        content: const Text(
          'سيتم حذف:\n'
          '• كل المحادثات والرسائل\n'
          '• سجل المكالمات\n'
          '• الأجهزة المحفوظة\n\n'
          'لا يمكن التراجع عن هذه العملية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // ✅ امسح كل البيانات من قاعدة البيانات
      await DatabaseHelper.instance.wipeAll();

      if (!mounted) return;

      _showSnack('تم حذف جميع البيانات', isSuccess: true);

      // انتظر قليلًا ثم أعد تحميل الإعدادات
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      await _loadSettings();
    } catch (e) {
      debugPrint('[Settings] clearAllData error: $e');
      if (!mounted) return;
      _showSnack('فشل حذف البيانات: $e');
    }
  }

  // ============================================
  // === أدوات ===
  // ============================================

  void _showSnack(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppTheme.successColor : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================
  // === الواجهة ===
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // ============================================
                // === قسم رأس الجهاز ===
                // ============================================
                _buildDeviceHeader(),

                // ============================================
                // === قسم المظهر ===
                // ============================================
                const _SectionTitle(title: 'المظهر'),
                _buildThemeSection(),

                // ============================================
                // === قسم الإشعارات ===
                // ============================================
                const _SectionTitle(title: 'الإشعارات والأصوات'),
                _buildNotificationsSection(),

                // ============================================
                // === قسم الشبكة ===
                // ============================================
                const _SectionTitle(title: 'معلومات الشبكة'),
                _buildNetworkSection(),

                // ============================================
                // === قسم البيانات ===
                // ============================================
                const _SectionTitle(title: 'البيانات'),
                _buildDataSection(),

                // ============================================
                // === قسم عن التطبيق ===
                // ============================================
                const _SectionTitle(title: 'عن التطبيق'),
                _buildAboutSection(),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // ============================================
  // === قسم رأس الجهاز ===
  // ============================================

  Widget _buildDeviceHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // الأيقونة
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.phone_android,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),

          // الاسم والحالة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'هذا الجهاز',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _deviceName.isEmpty ? 'جارٍ التحميل...' : _deviceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: Colors.greenAccent,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'يعمل',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // زر التعديل
          Material(
            color: Colors.white.withOpacity(0.15),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _editDeviceName,
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // === قسم المظهر ===
  // ============================================

  Widget _buildThemeSection() {
    return _SettingsCard(
      children: [
        RadioListTile<String>(
          value: 'light',
          groupValue: _themeMode,
          onChanged: (v) {
            if (v != null) _setThemeMode(v);
          },
          title: const Text('فاتح'),
          secondary: const Icon(Icons.light_mode_outlined),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        RadioListTile<String>(
          value: 'dark',
          groupValue: _themeMode,
          onChanged: (v) {
            if (v != null) _setThemeMode(v);
          },
          title: const Text('داكن'),
          secondary: const Icon(Icons.dark_mode_outlined),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        RadioListTile<String>(
          value: 'system',
          groupValue: _themeMode,
          onChanged: (v) {
            if (v != null) _setThemeMode(v);
          },
          title: const Text('حسب النظام'),
          secondary: const Icon(Icons.brightness_auto_outlined),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ],
    );
  }

  // ============================================
  // === قسم الإشعارات ===
  // ============================================

  Widget _buildNotificationsSection() {
    return _SettingsCard(
      children: [
        SwitchListTile(
          value: _soundEnabled,
          onChanged: _toggleSound,
          title: const Text('نغمة الرنين'),
          subtitle: const Text('تشغيل نغمة عند وصول مكالمة'),
          secondary: const Icon(Icons.volume_up_outlined),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        SwitchListTile(
          value: _vibrationEnabled,
          onChanged: _toggleVibration,
          title: const Text('الاهتزاز'),
          subtitle: const Text('اهتزاز الجهاز عند وصول مكالمة أو رسالة'),
          secondary: const Icon(Icons.vibration_outlined),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('إدارة الإشعارات'),
          trailing: const Icon(Icons.chevron_left),
          onTap: _manageNotifications,
        ),
      ],
    );
  }

  // ============================================
  // === قسم الشبكة ===
  // ============================================

  Widget _buildNetworkSection() {
    return _SettingsCard(
      children: [
        _InfoTile(
          icon: Icons.tag,
          title: 'معرّف الجهاز',
          value: _deviceId.isEmpty
              ? 'غير متوفر'
              : '${_deviceId.substring(0, _min(8, _deviceId.length))}...',
          onCopy: _deviceId.isEmpty
              ? null
              : () => _copyToClipboard(_deviceId, 'المعرّف'),
        ),
        _InfoTile(
          icon: Icons.wifi,
          title: 'عنوان IP',
          value: _localIp.isEmpty ? 'غير متصل' : _localIp,
          onCopy: _localIp.isEmpty
              ? null
              : () => _copyToClipboard(_localIp, 'عنوان IP'),
        ),
        _InfoTile(
          icon: Icons.settings_ethernet,
          title: 'منفذ التحكم',
          value: '${AppConstants.signalingPort}',
        ),
        _InfoTile(
          icon: Icons.sync_alt,
          title: 'منفذ الاكتشاف',
          value: '${AppConstants.discoveryPort}',
        ),
      ],
    );
  }

  // دالة مساعدة: الحد الأدنى بين رقمين
  int _min(int a, int b) => a < b ? a : b;

  // ============================================
  // === قسم البيانات ===
  // ============================================

  Widget _buildDataSection() {
    return _SettingsCard(
      children: [
        ListTile(
          leading: const Icon(
            Icons.delete_forever_outlined,
            color: AppTheme.errorColor,
          ),
          title: const Text(
            'إعادة تعيين التطبيق',
            style: TextStyle(color: AppTheme.errorColor),
          ),
          subtitle: const Text('حذف كل المحادثات والبيانات'),
          onTap: _clearAllData,
        ),
      ],
    );
  }

  // ============================================
  // === قسم عن التطبيق ===
  // ============================================

  Widget _buildAboutSection() {
    return _SettingsCard(
      children: [
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text(AppConstants.appName),
          subtitle: Text('الإصدار ${AppConstants.appVersion}'),
        ),
        const ListTile(
          leading: Icon(Icons.wifi_tethering),
          title: Text('شبكة محلية فقط'),
          subtitle: Text('لا يستخدم الإنترنت أو شبكات الاتصالات'),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('مفتوح المصدر'),
          subtitle: const Text('مرخّص تحت MIT License'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () {
            _showSnack('سيفتح رابط GitHub قريبًا');
          },
        ),
      ],
    );
  }
}

// ============================================================
// === عناصر مساعدة ===
// ============================================================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onCopy;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
          color: isDark
              ? AppTheme.darkTextSecondary
              : AppTheme.lightTextSecondary,
        ),
      ),
      trailing: onCopy != null
          ? IconButton(
              icon: const Icon(Icons.copy_outlined, size: 20),
              tooltip: 'نسخ',
              onPressed: onCopy,
            )
          : null,
    );
  }
}
