// lib/core/database/sqlite_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class SQLiteHelper {
  static final SQLiteHelper instance = SQLiteHelper._init();
  static Database? _database;
  static Future<Database>? _dbInitializer;

  SQLiteHelper._init();

  /// Thread-safe database getter preventing concurrent initialization races
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _dbInitializer ??= _initDB('neurotrace_v2.db');
    _database = await _dbInitializer;
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onConfigure: _onConfigure, // Enables WAL mode to prevent concurrent process locks
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  /// Enables Write-Ahead Logging (WAL) so background Kotlin writes never lock Dart reads
  Future _onConfigure(Database db) async {
    // FIX: sqflite requires rawQuery for PRAGMA statements that return a result (like journal_mode)
    await db.rawQuery('PRAGMA journal_mode = WAL;');
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE research_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        research_id TEXT NOT NULL,
        package_name TEXT NOT NULL,
        start_timestamp INTEGER NOT NULL,
        end_timestamp INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL,
        session_date TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        hour_of_day INTEGER NOT NULL,
        is_weekend INTEGER DEFAULT 0,
        is_late_night INTEGER DEFAULT 0,
        validation_version TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        last_sync_attempt INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE device_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        research_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        last_sync_attempt INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        research_id TEXT NOT NULL,
        package_name TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        last_sync_attempt INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE collector_health (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_type TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        app_version TEXT NOT NULL,
        collector_version TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        last_sync_attempt INTEGER DEFAULT 0
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE research_sessions ADD COLUMN is_synced INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE device_events ADD COLUMN is_synced INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE notifications ADD COLUMN is_synced INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE collector_health ADD COLUMN is_synced INTEGER DEFAULT 0');
    }

    if (oldVersion < 3) {
      List<String> tables = ['research_sessions', 'device_events', 'notifications', 'collector_health'];
      for (String table in tables) {
        await db.execute('ALTER TABLE $table ADD COLUMN sync_status INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE $table ADD COLUMN retry_count INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE $table ADD COLUMN last_sync_attempt INTEGER DEFAULT 0');
      }
    }
  }

  // --- Convenience Methods for UI & Services ---

  Future<int> insertSession(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('research_sessions', row);
  }

  Future<int> insertDeviceEvent(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('device_events', row);
  }

  Future<int> insertNotification(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('notifications', row);
  }

  Future<int> insertHealthEvent(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('collector_health', row);
  }

  // --- Encapsulated Query Helpers for TelemetrySyncEngine ---

  /// Safely fetches unsynced records from a given table
  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String tableName, {int limit = 250}) async {
    final db = await instance.database;
    return await db.query(
      tableName,
      where: 'sync_status != ?',
      whereArgs: [1], // 1 = Synced
      limit: limit,
    );
  }

  /// Transactionally marks a list of IDs as successfully synced
  Future<void> markRecordsSynced(String tableName, List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await instance.database;
    String idPlaceholders = ids.map((_) => '?').join(',');
    await db.rawUpdate(
      'UPDATE $tableName SET sync_status = 1, is_synced = 1 WHERE id IN ($idPlaceholders)',
      ids,
    );
  }

  /// Transactionally updates records to failed state with incremented retry count
  Future<void> markRecordsFailed(String tableName, List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await instance.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    String idPlaceholders = ids.map((_) => '?').join(',');
    await db.rawUpdate(
      'UPDATE $tableName SET sync_status = 2, retry_count = retry_count + 1, last_sync_attempt = ? WHERE id IN ($idPlaceholders)',
      [now, ...ids],
    );
  }

  Map<String, dynamic> buildFirebasePayload(String tableName, Map<dynamic, dynamic> rawRow) {
    Map<String, dynamic> payload = {
      'participant_uuid': 'local_test_uuid_001',
      'device_model': 'Galaxy M36 5G',
      'manufacturer': 'Samsung',
      'android_version': '14',
      'app_version': '2.0.0',
      'schema_version': '3.0.0',
      'source_table': tableName,
    };

    rawRow.forEach((key, value) {
      String stringKey = key.toString();
      if (stringKey != 'id' &&
          stringKey != 'is_synced' &&
          stringKey != 'sync_status' &&
          stringKey != 'retry_count' &&
          stringKey != 'last_sync_attempt') {
        payload[stringKey] = value;
      }
    });

    return payload;
  }
}