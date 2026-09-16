import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/discovery/device_discovery.dart';
import '../../core/discovery/discovered_device.dart';
import '../../core/messaging/message_service.dart';
import '../../data/database/database_helper.dart';
import '../theme/app_theme.dart';
import 'audio_call_screen.dart';
import 'video_call_screen.dart';

/// ============================================================
/// شاشة المحادثة
/// ============================================================
class ChatScreen extends StatefulWidget {
  final DiscoveredDevice peer;

  const ChatScreen({super.key, required this.peer});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // ============================================
  // === المراجع ===
  // ============================================
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  MessageService? _messageService;
  StreamSubscription<MessageEvent>? _eventSub;

  // ============================================
  // === الحالة ===
  // ============================================
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _replyToId;
  Map<String, dynamic>? _replyToMessage;
  bool _canSend = false;

  late String _conversationId;

  // ============================================
  // === دورة الحياة ===
  // ============================================

  @override
  void initState() {
    super.initState();

    _inputController.addListener(() {
      final can = _inputController.text.trim().isNotEmpty;
      if (can != _canSend) {
        setState(() => _canSend = can);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _messageService = context.read<MessageService>();
      final discovery = context.read<DeviceDiscovery>();
      _conversationId = _buildConversationId(
        discovery.deviceId,
        widget.peer.deviceId,
      );

      // استمع لأحداث الرسائل
      _eventSub = _messageService!.events.listen(_onMessageEvent);

      // حمّل الرسائل
      await _loadMessages();

      // علّم كقراءة
      await _messageService!.markConversationAsRead(widget.peer.deviceId);
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ============================================
  // === أدوات ===
  // ============================================

  String _buildConversationId(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}__${sorted[1]}';
  }

  Future<void> _loadMessages() async {
    try {
      final rows = await DatabaseHelper.instance.getMessages(
        conversationId: _conversationId,
      );
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _isLoading = false;
      });
      _scrollToBottom(animated: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onMessageEvent(MessageEvent event) {
    if (event.peerDeviceId != widget.peer.deviceId) return;

    switch (event.type) {
      case MessageEventType.received:
      case MessageEventType.sent:
      case MessageEventType.ack:
        _loadMessages();
        // علّم كقراءة عند الاستقبال والتفعيل
        if (event.type == MessageEventType.received) {
          _messageService?.markConversationAsRead(widget.peer.deviceId);
        }
        break;
      default:
        break;
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(max);
      }
    });
  }

  // ============================================
  // === الإرسال ===
  // ============================================

  Future<void> _sendText() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _messageService == null) return;

    _inputController.clear();

    final replyId = _replyToId;
    setState(() {
      _replyToId = null;
      _replyToMessage = null;
    });

    await _messageService!.sendText(
      peerDeviceId: widget.peer.deviceId,
      body: text,
      replyToId: replyId,
    );

    _scrollToBottom();
  }

  Future<void> _pickAndSendMedia(String type) async {
    // سنستخدم file_picker لإرسال أي نوع
    // لكن لتبسيط البداية، سنستخدم منتقي بسيط
    // يمكن لاحقًا توسيعه بـ image_picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('اختيار الوسائط سيُضاف في المرحلة التالية'),
      ),
    );
  }

  void _startReply(Map<String, dynamic> message) {
    setState(() {
      _replyToId = message['message_id'] as String;
      _replyToMessage = message;
    });
    _inputFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToMessage = null;
    });
  }

  // ============================================
  // === المكالمات ===
  // ============================================

  void _startAudioCall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AudioCallScreen(
          peer: widget.peer,
          isCaller: true,
        ),
      ),
    );
  }

  void _startVideoCall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          peer: widget.peer,
          isCaller: true,
        ),
      ),
    );
  }

  // ============================================
  // === الواجهة ===
  // ============================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final peerOnline = context.select<DeviceDiscovery, bool>(
      (d) => d.isDeviceOnline(widget.peer.deviceId),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _Avatar(name: widget.peer.name, online: peerOnline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.peer.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    peerOnline
                        ? 'متصل الآن'
                        : 'غير متصل • آخر ظهور ${_formatLastSeen(widget.peer.lastSeen)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            tooltip: 'مكالمة صوتية',
            onPressed: peerOnline ? _startAudioCall : null,
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'مكالمة فيديو',
            onPressed: peerOnline ? _startVideoCall : null,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              // TODO: خيارات إضافية
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear',
                child: Text('مسح المحادثة'),
              ),
              PopupMenuItem(
                value: 'block',
                child: Text('حظر'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ============================================
          // === قائمة الرسائل ===
          // ============================================
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkBackground
                    : const Color(0xFFECE5DD),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildMessagesList(isDark),
            ),
          ),

          // ============================================
          // === شريط الرد ===
          // ============================================
          if (_replyToMessage != null) _buildReplyBar(isDark),

          // ============================================
          // === شريط الإدخال ===
          // ============================================
          _buildInputBar(isDark, peerOnline),
        ],
      ),
    );
  }

  // ============================================
  // === بناء عناصر الواجهة ===
  // ============================================

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 72,
              color: AppTheme.primaryColor.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد رسائل بعد',
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
              'ابدأ بإرسال رسالة إلى ${widget.peer.name}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(bool isDark) {
    // نعرض الرسائل من الأقدم للأحدث (نعكس لأن الترتيب في DB تنازلي)
    final items = _messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final msg = items[index];
        final prev = index > 0 ? items[index - 1] : null;

        final showDate = _shouldShowDate(msg, prev);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate) _buildDateDivider(msg['created_at'] as int, isDark),
            _MessageBubble(
              message: msg,
              isDark: isDark,
              onReply: () => _startReply(msg),
              transfers: _messageService?.transfers ?? const {},
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowDate(
    Map<String, dynamic> msg,
    Map<String, dynamic>? prev,
  ) {
    if (prev == null) return true;
    final t1 = msg['created_at'] as int;
    final t2 = prev['created_at'] as int;
    final d1 = DateTime.fromMillisecondsSinceEpoch(t1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(t2);
    return d1.day != d2.day ||
        d1.month != d2.month ||
        d1.year != d2.year;
  }

  Widget _buildDateDivider(int timestamp, bool isDark) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.35)
                : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(date),
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyBar(bool isDark) {
    final msg = _replyToMessage!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (msg['is_outgoing'] == 1) ? 'أنت' : widget.peer.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _previewText(msg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark, bool peerOnline) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // زر المرفقات
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: AppTheme.primaryColor,
              onPressed: peerOnline ? () => _showAttachMenu() : null,
            ),

            // حقل النص
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkBackground
                      : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocus,
                  enabled: peerOnline,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: peerOnline ? 'اكتب رسالة...' : 'الجهاز غير متصل',
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  style: TextStyle(
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),

            // زر الإرسال
            Material(
              color: _canSend
                  ? AppTheme.primaryColor
                  : AppTheme.primaryColor.withOpacity(0.35),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _canSend && peerOnline ? _sendText : null,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkSurface
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _attachOption(
                icon: Icons.image_outlined,
                label: 'صورة',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendMedia(AppConstants.mediaImage);
                },
              ),
              _attachOption(
                icon: Icons.videocam_outlined,
                label: 'فيديو',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendMedia(AppConstants.mediaVideo);
                },
              ),
              _attachOption(
                icon: Icons.insert_drive_file_outlined,
                label: 'ملف',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendMedia(AppConstants.mediaFile);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ============================================
  // === تنسيقات النصوص ===
  // ============================================

  String _previewText(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    switch (type) {
      case AppConstants.mediaText:
        return (msg['body'] as String?) ?? '';
      case AppConstants.mediaImage:
        return '📷 صورة';
      case AppConstants.mediaVideo:
        return '🎥 فيديو';
      case AppConstants.mediaAudio:
        return '🎵 مقطع صوتي';
      case AppConstants.mediaFile:
        return '📎 ملف';
      default:
        return 'رسالة';
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'أمس';
    if (diff < 7) return 'منذ $diff أيام';
    return DateFormat('d MMM yyyy', 'ar').format(d);
  }

  String _formatLastSeen(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'قبل لحظات';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    return 'قبل ${diff.inDays} يوم';
  }
}

// ============================================================
// === الأفاتار ===
// ============================================================
class _Avatar extends StatelessWidget {
  final String name;
  final bool online;

  const _Avatar({required this.name, required this.online});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: online ? AppTheme.successColor : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// === فقاعة الرسالة ===
// ============================================================
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isDark;
  final VoidCallback onReply;
  final Map<String, double> transfers;

  const _MessageBubble({
    required this.message,
    required this.isDark,
    required this.onReply,
    required this.transfers,
  });

  @override
  Widget build(BuildContext context) {
    final isOutgoing = (message['is_outgoing'] as int?) == 1;
    final messageId = message['message_id'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: isOutgoing
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: GestureDetector(
          onLongPress: onReply,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isOutgoing
                  ? (isDark
                      ? AppTheme.darkOutgoingBubble
                      : AppTheme.lightOutgoingBubble)
                  : (isDark
                      ? AppTheme.darkIncomingBubble
                      : AppTheme.lightIncomingBubble),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isOutgoing ? 14 : 3),
                bottomRight: Radius.circular(isOutgoing ? 3 : 14),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ============================================
                // === محتوى الرسالة حسب النوع ===
                // ============================================
                _buildContent(isDark),

                // ============================================
                // === شريط التقدم ===
                // ============================================
                if (transfers.containsKey(messageId))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: transfers[messageId],
                        minHeight: 3,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),

                // ============================================
                // === الوقت والحالة ===
                // ============================================
                Padding(
                  padding: const EdgeInsets.only(
                    left: 10,
                    right: 10,
                    bottom: 5,
                    top: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(
                          DateTime.fromMillisecondsSinceEpoch(
                            message['created_at'] as int,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white.withOpacity(0.7)
                              : Colors.black.withOpacity(0.5),
                        ),
                      ),
                      if (isOutgoing) ...[
                        const SizedBox(width: 4),
                        _statusIcon(message['status'] as String?),
                      ],
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

  Widget _buildContent(bool isDark) {
    final type = message['type'] as String?;

    switch (type) {
      case AppConstants.mediaImage:
        return _buildMediaPreview('📷 صورة');

      case AppConstants.mediaVideo:
        return _buildMediaPreview('🎥 فيديو');

      case AppConstants.mediaAudio:
        return _buildMediaPreview('🎵 مقطع صوتي');

      case AppConstants.mediaFile:
        final fileName = message['file_name'] as String? ?? 'ملف';
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        );

      case AppConstants.mediaText:
      default:
        final body = message['body'] as String? ?? '';
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          child: Text(
            body,
            style: TextStyle(
              fontSize: 15,
              height: 1.35,
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
            ),
          ),
        );
    }
  }

  Widget _buildMediaPreview(String label) {
    return Container(
      width: 200,
      height: 140,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }

  Widget _statusIcon(String? status) {
    switch (status) {
      case 'pending':
        return const Icon(
          Icons.schedule,
          size: 14,
          color: Colors.grey,
        );
      case 'sent':
        return const Icon(
          Icons.check,
          size: 15,
          color: Colors.grey,
        );
      case 'delivered':
        return const Icon(
          Icons.done_all,
          size: 15,
          color: Colors.grey,
        );
      case 'read':
        return const Icon(
          Icons.done_all,
          size: 15,
          color: Color(0xFF4FC3F7),
        );
      case 'failed':
        return const Icon(
          Icons.error_outline,
          size: 14,
          color: AppTheme.errorColor,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _formatTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
