import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants.dart';

/// ============================================================
/// مدير قاعدة البيانات المحلية (SQLite)
/// ============================================================
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Database get db {
    if (_db == null) {
      throw StateError(
        'قاعدة البيانات لم تُهيَّأ بعد. استدعِ DatabaseHelper.instance.init() أولًا.',
      );
    }
    return _db!;
  }

  // ============================================
  // === أسماء الجداول ===
  // ============================================
  static const String tableDevices = 'devices';
  static const String tableConversations = 'conversations';
  static const String tableMessages = 'messages';
  static const String tableCallLogs = 'call_logs';

  // ============================================
  // === التهيئة ===
  // ============================================
  Future<void> init() async {
    if (_db != null) return;

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, AppConstants.databaseName);

    _db = await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // جدول الأجهزة
    await db.execute('''
      CREATE TABLE $tableDevices (
        device_id     TEXT PRIMARY KEY,
        number        TEXT NOT NULL DEFAULT '',
        name          TEXT NOT NULL,
        ip_address    TEXT NOT NULL,
        port          INTEGER NOT NULL,
        capabilities  TEXT NOT NULL DEFAULT '[]',
        last_seen     INTEGER NOT NULL,
        is_favorite   INTEGER NOT NULL DEFAULT 0,
        is_blocked    INTEGER NOT NULL DEFAULT 0,
        public_key    TEXT,
        created_at    INTEGER NOT NULL
      )
    ''');

    // جدول المحادثات
    await db.execute('''
      CREATE TABLE $tableConversations (
        conversation_id     TEXT PRIMARY KEY,
        peer_device_id      TEXT NOT NULL,
        last_message        TEXT,
        last_message_type   TEXT,
        last_message_time   INTEGER,
        unread_count        INTEGER NOT NULL DEFAULT 0,
        is_pinned           INTEGER NOT NULL DEFAULT 0,
        is_archived         INTEGER NOT NULL DEFAULT 0,
        created_at          INTEGER NOT NULL,
        FOREIGN KEY (peer_device_id) REFERENCES $tableDevices(device_id)
          ON DELETE CASCADE
      )
    ''');

    // جدول الرسائل (مع is_pinned)
    await db.execute('''
      CREATE TABLE $tableMessages (
        message_id       TEXT PRIMARY KEY,
        conversation_id  TEXT NOT NULL,
        sender_id        TEXT NOT NULL,
        receiver_id      TEXT NOT NULL,
        type             TEXT NOT NULL,
        body             TEXT,
        file_path        TEXT,
        file_name        TEXT,
        file_size        INTEGER,
        mime_type        TEXT,
        duration_ms      INTEGER,
        status           TEXT NOT NULL DEFAULT 'pending',
        is_outgoing      INTEGER NOT NULL DEFAULT 0,
        is_pinned        INTEGER NOT NULL DEFAULT 0,
        reply_to_id      TEXT,
        created_at       INTEGER NOT NULL,
        delivered_at     INTEGER,
        read_at          INTEGER,
        FOREIGN KEY (conversation_id) REFERENCES $tableConversations(conversation_id)
          ON DELETE CASCADE
      )
    ''');

    // جدول سجل المكالمات
    await db.execute('''
      CREATE TABLE $tableCallLogs (
        call_id          TEXT PRIMARY KEY,
        peer_device_id   TEXT NOT NULL,
        peer_name        TEXT NOT NULL,
        type             TEXT NOT NULL,
        direction        TEXT NOT NULL,
        state            TEXT NOT NULL,
        started_at       INTEGER NOT NULL,
        ended_at         INTEGER,
        duration_seconds INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // الفهارس
    await db.execute(
      'CREATE INDEX idx_messages_conversation ON $tableMessages(conversation_id)',
    );
    await db.execute(
      'CREATE INDEX idx_messages_created ON $tableMessages(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_messages_pinned ON $tableMessages(is_pinned)',
    );
    await db.execute(
      'CREATE INDEX idx_conversations_peer ON $tableConversations(peer_device_id)',
    );
    await db.execute(
      'CREATE INDEX idx_call_logs_started ON $tableCallLogs(started_at)',
    );
    await db.execute(
      'CREATE INDEX idx_devices_last_seen ON $tableDevices(last_seen)',
    );
    await db.execute(
      'CREATE INDEX idx_devices_number ON $tableDevices(number)',
    );
  }

  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // v1 → v2: إضافة رقم الاتصال
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE $tableDevices ADD COLUMN number TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'CREATE INDEX idx_devices_number ON $tableDevices(number)',
      );
    }

    // v2 → v3: إضافة تثبيت الرسائل
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE $tableMessages ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'CREATE INDEX idx_messages_pinned ON $tableMessages(is_pinned)',
      );
    }
  }

  // ============================================
  // === عمليات عامة ===
  // ============================================
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> wipeAll() async {
    await db.delete(tableMessages);
    await db.delete(tableConversations);
    await db.delete(tableDevices);
    await db.delete(tableCallLogs);
  }

  // ============================================
  // === CRUD: الأجهزة ===
  // ============================================
  Future<int> upsertDevice(Map<String, dynamic> device) async {
    return db.insert(
      tableDevices,
      device,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllDevices() async {
    return db.query(tableDevices, orderBy: 'last_seen DESC');
  }

  Future<Map<String, dynamic>?> getDevice(String deviceId) async {
    final rows = await db.query(
      tableDevices,
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getDeviceByNumber(String number) async {
    final rows = await db.query(
      tableDevices,
      where: 'number = ?',
      whereArgs: [number],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<bool> isNumberUsedByOther(
    String number,
    String excludeDeviceId,
  ) async {
    final rows = await db.query(
      tableDevices,
      where: 'number = ? AND device_id != ?',
      whereArgs: [number, excludeDeviceId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> getAllUsedNumbers() async {
    final rows = await db.query(
      tableDevices,
      columns: ['number'],
      where: "number != ''",
    );
    return rows.map((r) => r['number'] as String).toSet();
  }

  Future<int> deleteDevice(String deviceId) async {
    return db.delete(
      tableDevices,
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<int> updateDeviceLastSeen(String deviceId, int timestamp) async {
    return db.update(
      tableDevices,
      {'last_seen': timestamp},
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  // ============================================
  // === CRUD: المحادثات ===
  // ============================================
  Future<int> upsertConversation(Map<String, dynamic> conversation) async {
    return db.insert(
      tableConversations,
      conversation,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllConversations() async {
    return db.query(
      tableConversations,
      orderBy: 'is_pinned DESC, last_message_time DESC',
    );
  }

  Future<Map<String, dynamic>?> getConversation(String conversationId) async {
    final rows = await db.query(
      tableConversations,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getConversationByPeer(String peerId) async {
    final rows = await db.query(
      tableConversations,
      where: 'peer_device_id = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> updateConversationLastMessage({
    required String conversationId,
    required String lastMessage,
    required String lastMessageType,
    required int lastMessageTime,
  }) async {
    return db.update(
      tableConversations,
      {
        'last_message': lastMessage,
        'last_message_type': lastMessageType,
        'last_message_time': lastMessageTime,
      },
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<int> incrementUnread(String conversationId) async {
    return db.rawUpdate(
      'UPDATE $tableConversations SET unread_count = unread_count + 1 '
      'WHERE conversation_id = ?',
      [conversationId],
    );
  }

  Future<int> resetUnread(String conversationId) async {
    return db.update(
      tableConversations,
      {'unread_count': 0},
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<int> deleteConversation(String conversationId) async {
    return db.delete(
      tableConversations,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  // ============================================
  // === إدارة المحادثات: تثبيت / أرشفة ===
  // ============================================

  Future<List<Map<String, dynamic>>> getVisibleConversations() async {
    return db.query(
      tableConversations,
      where: 'is_archived = 0',
      orderBy: 'is_pinned DESC, last_message_time DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getArchivedConversations() async {
    return db.query(
      tableConversations,
      where: 'is_archived = 1',
      orderBy: 'last_message_time DESC',
    );
  }

  Future<int> getArchivedCount() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableConversations '
      'WHERE is_archived = 1',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> togglePin(String conversationId, bool isPinned) async {
    return db.update(
      tableConversations,
      {'is_pinned': isPinned ? 1 : 0},
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<int> toggleArchive(String conversationId, bool isArchived) async {
    return db.update(
      tableConversations,
      {'is_archived': isArchived ? 1 : 0},
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<bool> isPinned(String conversationId) async {
    final result = await db.query(
      tableConversations,
      columns: ['is_pinned'],
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    if (result.isEmpty) return false;
    return (result.first['is_pinned'] as int?) == 1;
  }

  Future<bool> isArchived(String conversationId) async {
    final result = await db.query(
      tableConversations,
      columns: ['is_archived'],
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    if (result.isEmpty) return false;
    return (result.first['is_archived'] as int?) == 1;
  }

  // ============================================
  // === حظر الأجهزة ===
  // ============================================

  Future<int> toggleBlock(String deviceId, bool isBlocked) async {
    return db.update(
      tableDevices,
      {'is_blocked': isBlocked ? 1 : 0},
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<bool> isDeviceBlocked(String deviceId) async {
    final result = await db.query(
      tableDevices,
      columns: ['is_blocked'],
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    if (result.isEmpty) return false;
    return (result.first['is_blocked'] as int?) == 1;
  }

  Future<List<Map<String, dynamic>>> getBlockedDevices() async {
    return db.query(
      tableDevices,
      where: 'is_blocked = 1',
      orderBy: 'name ASC',
    );
  }

  Future<int> getBlockedCount() async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableDevices '
      'WHERE is_blocked = 1',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<Set<String>> getBlockedDeviceIds() async {
    final rows = await db.query(
      tableDevices,
      columns: ['device_id'],
      where: 'is_blocked = 1',
    );
    return rows.map((r) => r['device_id'] as String).toSet();
  }

  // ============================================
  // === CRUD: الرسائل ===
  // ============================================
  Future<int> insertMessage(Map<String, dynamic> message) async {
    return db.insert(
      tableMessages,
      message,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getMessages({
    required String conversationId,
    int? limit,
    int? offset,
  }) async {
    return db.query(
      tableMessages,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    final rows = await db.query(
      tableMessages,
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> updateMessageStatus(String messageId, String status) async {
    return db.update(
      tableMessages,
      {'status': status},
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> markMessageDelivered(String messageId, int timestamp) async {
    return db.update(
      tableMessages,
      {'status': 'delivered', 'delivered_at': timestamp},
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> markMessageRead(String messageId, int timestamp) async {
    return db.update(
      tableMessages,
      {'status': 'read', 'read_at': timestamp},
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> deleteMessage(String messageId) async {
    return db.delete(
      tableMessages,
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> deleteConversationMessages(String conversationId) async {
    return db.delete(
      tableMessages,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  // ============================================
  // === تثبيت الرسائل (جديد) ===
  // ============================================

  /// تفعيل/إلغاء تثبيت رسالة
  Future<int> toggleMessagePin(String messageId, bool isPinned) async {
    return db.update(
      tableMessages,
      {'is_pinned': isPinned ? 1 : 0},
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  /// هل الرسالة مثبتة؟
  Future<bool> isMessagePinned(String messageId) async {
    final result = await db.query(
      tableMessages,
      columns: ['is_pinned'],
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (result.isEmpty) return false;
    return (result.first['is_pinned'] as int?) == 1;
  }

  /// كل الرسائل المثبتة في محادثة (الأحدث أولًا)
  Future<List<Map<String, dynamic>>> getPinnedMessages(
    String conversationId,
  ) async {
    return db.query(
      tableMessages,
      where: 'conversation_id = ? AND is_pinned = 1',
      whereArgs: [conversationId],
      orderBy: 'created_at DESC',
    );
  }

  /// عدد الرسائل المثبتة في محادثة
  Future<int> getPinnedMessagesCount(String conversationId) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableMessages '
      'WHERE conversation_id = ? AND is_pinned = 1',
      [conversationId],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// إلغاء تثبيت كل الرسائل في محادثة
  Future<int> unpinAllMessages(String conversationId) async {
    return db.update(
      tableMessages,
      {'is_pinned': 0},
      where: 'conversation_id = ? AND is_pinned = 1',
      whereArgs: [conversationId],
    );
  }

  // ============================================
  // === CRUD: سجل المكالمات ===
  // ============================================
  Future<int> insertCallLog(Map<String, dynamic> callLog) async {
    return db.insert(
      tableCallLogs,
      callLog,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllCallLogs({int? limit}) async {
    return db.query(
      tableCallLogs,
      orderBy: 'started_at DESC',
      limit: limit,
    );
  }

  Future<int> updateCallLog({
    required String callId,
    required String state,
    required int endedAt,
    required int durationSeconds,
  }) async {
    return db.update(
      tableCallLogs,
      {
        'state': state,
        'ended_at': endedAt,
        'duration_seconds': durationSeconds,
      },
      where: 'call_id = ?',
      whereArgs: [callId],
    );
  }

  Future<int> deleteCallLog(String callId) async {
    return db.delete(
      tableCallLogs,
      where: 'call_id = ?',
      whereArgs: [callId],
    );
  }

  // ============================================
  // === إحصائيات جهاز معين ===
  // ============================================

  Future<int> getMessageCountForPeer(String peerDeviceId) async {
    final conv = await getConversationByPeer(peerDeviceId);
    if (conv == null) return 0;

    final conversationId = conv['conversation_id'] as String;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableMessages '
      'WHERE conversation_id = ?',
      [conversationId],
    );

    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getCallCountForPeer(String peerDeviceId) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableCallLogs '
      'WHERE peer_device_id = ?',
      [peerDeviceId],
    );

    return (result.first['count'] as int?) ?? 0;
  }

  Future<int?> getFirstSeenForDevice(String deviceId) async {
    final device = await getDevice(deviceId);
    if (device == null) return null;
    return device['created_at'] as int?;
  }

  Future<int> toggleFavorite(String deviceId, bool isFavorite) async {
    return db.update(
      tableDevices,
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<bool> isFavorite(String deviceId) async {
    final result = await db.query(
      tableDevices,
      columns: ['is_favorite'],
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    if (result.isEmpty) return false;
    return (result.first['is_favorite'] as int?) == 1;
  }

  Future<int> updateDeviceName(String deviceId, String newName) async {
    return db.update(
      tableDevices,
      {'name': newName},
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  // ============================================
  // === البحث العالمي ===
  // ============================================

  Future<List<Map<String, dynamic>>> searchMessages({
    required String query,
    int limit = 200,
  }) async {
    if (query.trim().isEmpty) return [];

    final q = '%${query.toLowerCase().trim()}%';

    return db.rawQuery('''
      SELECT 
        m.*,
        d.name AS peer_name,
        d.number AS peer_number,
        d.device_id AS peer_id,
        c.peer_device_id AS conversation_peer_id
      FROM $tableMessages m
      LEFT JOIN $tableConversations c 
        ON m.conversation_id = c.conversation_id
      LEFT JOIN $tableDevices d 
        ON c.peer_device_id = d.device_id
      WHERE 
        (m.type = 'text' AND LOWER(m.body) LIKE ?) OR
        (m.type = 'file' AND LOWER(m.file_name) LIKE ?)
      ORDER BY m.created_at DESC
      LIMIT ?
    ''', [q, q, limit]);
  }

  Future<Map<String, int>> getSearchStats(String query) async {
    if (query.trim().isEmpty) {
      return {'total': 0, 'conversations': 0};
    }

    final q = '%${query.toLowerCase().trim()}%';

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) AS total,
        COUNT(DISTINCT m.conversation_id) AS conversations
      FROM $tableMessages m
      WHERE 
        (m.type = 'text' AND LOWER(m.body) LIKE ?) OR
        (m.type = 'file' AND LOWER(m.file_name) LIKE ?)
    ''', [q, q]);

    if (result.isEmpty) return {'total': 0, 'conversations': 0};

    return {
      'total': (result.first['total'] as int?) ?? 0,
      'conversations': (result.first['conversations'] as int?) ?? 0,
    };
  }
}
