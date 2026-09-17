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
    // --------------------------------------------
    // جدول الأجهزة (مع عمود number الجديد)
    // --------------------------------------------
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
        reply_to_id      TEXT,
        created_at       INTEGER NOT NULL,
        delivered_at     INTEGER,
        read_at          INTEGER,
        FOREIGN KEY (conversation_id) REFERENCES $tableConversations(conversation_id)
          ON DELETE CASCADE
      )
    ''');

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

  // ============================================
  // === الترقية (من الإصدار 1 إلى 2) ===
  // ============================================
  Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // إضافة عمود number لجدول الأجهزة
      await db.execute(
        "ALTER TABLE $tableDevices ADD COLUMN number TEXT NOT NULL DEFAULT ''",
      );
      // فهرس للبحث السريع
      await db.execute(
        'CREATE INDEX idx_devices_number ON $tableDevices(number)',
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

  /// بحث سريع بالرقم
  Future<Map<String, dynamic>?> getDeviceByNumber(String number) async {
    final rows = await db.query(
      tableDevices,
      where: 'number = ?',
      whereArgs: [number],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// هل الرقم مستخدم من قبل جهاز آخر؟
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

  /// كل الأرقام المستخدمة حاليًا
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
}
