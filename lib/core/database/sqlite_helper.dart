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
      version: 4, // Upgraded to v4 for the Raw Telemetry Architecture
      onConfigure: _onConfigure, // Enables WAL mode to prevent concurrent process locks
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  /// Enables Write-Ahead Logging (WAL) so background Kotlin writes never lock Dart reads
  Future _onConfigure(Database db) async {
    await db.rawQuery('PRAGMA journal_mode = WAL;');
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  /// Fresh install logic (Version 4+ will only create the new raw telemetry tables)
  Future _createDB(Database db, int version) async {
    await _createRawTables(db);
  }

  /// Extracted creation logic so it can be reused safely during migration
  Future _createRawTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS raw_usage_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        packageName TEXT,
        className TEXT,
        eventType INTEGER,
        timestamp INTEGER,
        instanceId INTEGER,
        taskRootPackageName TEXT,
        taskRootClassName TEXT,
        standbyBucket INTEGER,
        configuration TEXT,
        shortcutId TEXT,
        notificationChannelId TEXT,
        locusId TEXT,
        sync_status INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        last_sync_attempt INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS raw_usage_stats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        packageName TEXT,
        firstTimeStamp INTEGER,
        lastTimeStamp INTEGER,
        lastTimeUsed INTEGER,
        totalTimeInForeground INTEGER,
        lastTimeVisible INTEGER,
        totalTimeVisible INTEGER,
        lastTimeForegroundServiceUsed INTEGER,
        totalTimeForegroundServiceUsed INTEGER,
        sync_status INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        last_sync_attempt INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS raw_system_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER,
        event_type TEXT,
        value TEXT,
        extras TEXT,
        source TEXT,
        sync_status INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        last_sync_attempt INTEGER DEFAULT 0
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Legacy migrations (v1 to v3) can be preserved here if needed
    if (oldVersion < 2) {
      // Ignore executing old alters if the tables don't exist, wrapped in try-catch to be safe
      try {
        await db.execute('ALTER TABLE research_sessions ADD COLUMN is_synced INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE device_events ADD COLUMN is_synced INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE notifications ADD COLUMN is_synced INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE collector_health ADD COLUMN is_synced INTEGER DEFAULT 0');
      } catch (_) {}
    }

    if (oldVersion < 3) {
      try {
        List<String> tables = ['research_sessions', 'device_events', 'notifications', 'collector_health'];
        for (String table in tables) {
          await db.execute('ALTER TABLE $table ADD COLUMN sync_status INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE $table ADD COLUMN retry_count INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE $table ADD COLUMN last_sync_attempt INTEGER DEFAULT 0');
        }
      } catch (_) {}
    }

    // V4 Migration: The Safe Transition to Raw Telemetry
    if (oldVersion < 4) {
      // We explicitly DO NOT drop the old tables here.
      // This preserves any unsynced v3 data on the device in case a manual extraction is required.
      // We safely build the new architecture alongside the old one.
      await _createRawTables(db);
    }
  }

  // --- Convenience Methods for UI & Services ---

  Future<int> insertRawUsageEvent(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('raw_usage_events', row);
  }

  Future<int> insertRawUsageStat(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('raw_usage_stats', row);
  }

  Future<int> insertRawSystemEvent(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('raw_system_events', row);
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
      'UPDATE $tableName SET sync_status = 1 WHERE id IN ($idPlaceholders)',
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

  /// Builds a clean payload for Firestore, stripping internal SQLite tracking keys
  Map<String, dynamic> buildFirebasePayload(String tableName, Map<dynamic, dynamic> rawRow) {
    Map<String, dynamic> payload = {
      // NOTE: Device metadata (model, OS, etc.) is no longer hardcoded here.
      // It should be dynamically injected by the TelemetrySyncEngine right before upload
      // using a package like `device_info_plus` to guarantee accuracy.
      'schema_version': '4.0.0',
      'source_table': tableName,
    };

    rawRow.forEach((key, value) {
      String stringKey = key.toString();
      // Filter out internal SQLite syncing state columns
      if (stringKey != 'id' &&
          stringKey != 'sync_status' &&
          stringKey != 'retry_count' &&
          stringKey != 'last_sync_attempt') {
        payload[stringKey] = value;
      }
    });

    return payload;
  }
}