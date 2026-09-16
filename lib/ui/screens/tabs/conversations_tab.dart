import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/discovery/device_discovery.dart';
import '../../../core/discovery/discovered_device.dart';
import '../../../core/messaging/message_service.dart';
import '../../../data/database/database_helper.dart';
import '../../theme/app_theme.dart';
import '../chat_screen.dart';

/// ============================================================
/// تبويب المحادثات
/// ============================================================
class ConversationsTab extends StatefulWidget {
  const ConversationsTab({super.key});

  @override
  State<ConversationsTab> createState() => _ConversationsTabState();
}

class _ConversationsTabState extends State<ConversationsTab> {
  // ============================================
  // === الحالة ===
  // ============================================
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  MessageService? _messageService;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageService = context.read<MessageService>();
      _messageService!.addListener(_onMessagesChanged);
      _loadConversations();
    });
  }

  @override
  void dispose() {
    _messageService?.removeListener(_onMessagesChanged);
    super.dispose();
  }

  // ============================================
  // === الاستماع للتغيّرات ===
  // ============================================

  void _onMessagesChanged() {
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final rows = await DatabaseHelper.instance.getAllConversations();
      if (!mounted) return;
      setState(() {
        _conversations = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ============================================
  // === العمليات ===
  // ============================================

  Future<void> _deleteConversation(String conversationId) async {
    await DatabaseHelper.instance.deleteConversation(conversationId);
    await DatabaseHelper.instance.deleteConversationMessages(conversationId);
    await _loadConversations();
  }

  Future<void> _openConversation(Map<String, dynamic> conv) async {
    final peerId = conv['peer_device_id'] as String;

    final discovery = context.read<DeviceDiscovery>();
    final peer = discovery.getDevice(peerId);

    if (peer == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الجهاز غير متوفر')),
        );
      }
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(peer: peer),
      ),
    );

    // تحديث عند العودة
    _loadConversations();
  }

  // ============================================
  // === الواجهة ===
  // ============================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_conversations.isEmpty) {
      return const _EmptyConversationsState();
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
        itemBuilder: (context, index) {
          final conv = _conversations[index];
          return _ConversationTile(
            conversation: conv,
            onTap: () => _openConversation(conv),
            onDelete: () => _confirmDelete(conv),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> conv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المحادثة'),
        content: const Text(
          'سيتم حذف كل الرسائل في هذه المحادثة نهائيًا. هل أنت متأكد؟',
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
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _deleteConversation(conv['conversation_id'] as String);
    }
  }
}

// ============================================================
// === صف محادثة ===
// ============================================================
class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final peerId = conversation['peer_device_id'] as String;
    final lastMessage = conversation['last_message'] as String? ?? '';
    final lastType = conversation['last_message_type'] as String? ?? 'text';
    final lastTime = conversation['last_message_time'] as int?;
    final unread = conversation['unread_count'] as int? ?? 0;

    // راقب حالة الاتصال لهذا الجهاز
    final isOnline = context.select<DeviceDiscovery, bool>(
      (d) => d.isDeviceOnline(peerId),
    );

    final peer = context.select<DeviceDiscovery, DiscoveredDevice?>(
      (d) => d.getDevice(peerId),
    );

    final displayName = peer?.name ?? 'جهاز محذوف';

    return Dismissible(
      key: ValueKey(conversation['conversation_id']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppTheme.errorColor,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('حذف المحادثة'),
                content: const Text(
                  'سيتم حذف كل الرسائل في هذه المحادثة نهائيًا.',
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
                    child: const Text('حذف'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? AppTheme.darkSurface : Colors.white,
            child: Row(
              children: [
                // ============================================
                // === الأفاتار ===
                // ============================================
                _ConversationAvatar(
                  name: displayName,
                  isOnline: isOnline,
                ),

                const SizedBox(width: 14),

                // ============================================
                // === الاسم وآخر رسالة ===
                // ============================================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // الصف الأول: الاسم + الوقت
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.lightTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lastTime != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(lastTime),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: unread > 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: unread > 0
                                    ? AppTheme.primaryColor
                                    : (isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 5),

                      // الصف الثاني: آخر رسالة + شارة غير مقروء
                      Row(
                        children: [
                          if (lastType != AppConstants.mediaText) ...[
                            Icon(
                              _iconForType(lastType),
                              size: 15,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              _previewText(lastMessage, lastType),
                              style: TextStyle(
                                fontSize: 14,
                                color: unread > 0
                                    ? (isDark
                                        ? AppTheme.darkTextPrimary
                                        : AppTheme.lightTextPrimary)
                                    : (isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.lightTextSecondary),
                                fontWeight: unread > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          if (unread > 0) ...[
                            const SizedBox(width: 8),
                            _UnreadBadge(count: unread),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case AppConstants.mediaImage:
        return Icons.image_outlined;
      case AppConstants.mediaVideo:
        return Icons.videocam_outlined;
      case AppConstants.mediaAudio:
        return Icons.mic_none;
      case AppConstants.mediaFile:
        return Icons.insert_drive_file_outlined;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  String _previewText(String text, String type) {
    switch (type) {
      case AppConstants.mediaImage:
        return 'صورة';
      case AppConstants.mediaVideo:
        return 'فيديو';
      case AppConstants.mediaAudio:
        return 'مقطع صوتي';
      case AppConstants.mediaFile:
        return text.isEmpty ? 'ملف' : text;
      default:
        return text.isEmpty ? 'لا توجد رسائل' : text;
    }
  }

  String _formatTime(int timestamp) {
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) {
      return DateFormat('h:mm a', 'ar').format(d);
    }
    if (diff == 1) {
      return 'أمس';
    }
    if (diff < 7) {
      // اسم اليوم
      return DateFormat('EEEE', 'ar').format(d);
    }
    return DateFormat('d/M/yyyy', 'ar').format(d);
  }
}

// ============================================================
// === الأفاتار ===
// ============================================================
class _ConversationAvatar extends StatelessWidget {
  final String name;
  final bool isOnline;

  const _ConversationAvatar({
    required this.name,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 54,
          height: 54,
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
                      Colors.grey.shade400,
                      Colors.grey.shade600,
                    ],
            ),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Positioned(
          bottom: 1,
          right: 1,
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
// === شارة غير المقروء ===
// ============================================================
class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
      ),
    );
  }
}

// ============================================================
// === حالة فارغة ===
// ============================================================
class _EmptyConversationsState extends StatelessWidget {
  const _EmptyConversationsState();

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
                Icons.chat_bubble_outline,
                size: 52,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد محادثات',
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
              'اذهب إلى تبويب "الأجهزة" وابدأ محادثة\nمع جهاز على نفس شبكة الواي فاي',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textColor, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
