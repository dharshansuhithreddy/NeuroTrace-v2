package com.neurotrace_v2.neurotrace_v2

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.os.Build
import android.util.Log

class DatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "neurotrace_v2.db"
        private const val DATABASE_VERSION = 4 // Incremented for new raw schema

        const val TABLE_RAW_USAGE_EVENTS = "raw_usage_events"
        const val TABLE_RAW_USAGE_STATS = "raw_usage_stats"
        const val TABLE_RAW_SYSTEM_EVENTS = "raw_system_events"
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""
            CREATE TABLE $TABLE_RAW_USAGE_EVENTS (
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
        """)

        db.execSQL("""
            CREATE TABLE $TABLE_RAW_USAGE_STATS (
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
        """)

        db.execSQL("""
            CREATE TABLE $TABLE_RAW_SYSTEM_EVENTS (
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
        """)
        Log.d("NeuroTrace_DB", "Native DB Created matching Raw Telemetry Schema.")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Drop older tables if upgrading to raw pipeline
        db.execSQL("DROP TABLE IF EXISTS research_sessions")
        db.execSQL("DROP TABLE IF EXISTS device_events")
        db.execSQL("DROP TABLE IF EXISTS notifications")
        db.execSQL("DROP TABLE IF EXISTS collector_health")
        onCreate(db)
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.enableWriteAheadLogging() // Crucial for concurrent Flutter reads and Android writes
    }

    fun insertRawUsageEvent(
        packageName: String?, className: String?, eventType: Int, timestamp: Long,
        instanceId: Int?, taskRootPackageName: String?, taskRootClassName: String?,
        standbyBucket: Int?, configuration: String?, shortcutId: String?,
        notificationChannelId: String?, locusId: String?
    ) {
        val values = ContentValues().apply {
            put("packageName", packageName)
            put("className", className)
            put("eventType", eventType)
            put("timestamp", timestamp)
            put("instanceId", instanceId)
            put("taskRootPackageName", taskRootPackageName)
            put("taskRootClassName", taskRootClassName)
            put("standbyBucket", standbyBucket)
            put("configuration", configuration)
            put("shortcutId", shortcutId)
            put("notificationChannelId", notificationChannelId)
            put("locusId", locusId)
            put("sync_status", 0)
        }
        writableDatabase.insert(TABLE_RAW_USAGE_EVENTS, null, values)
    }

    fun insertRawUsageStat(
        packageName: String?, firstTimeStamp: Long, lastTimeStamp: Long, lastTimeUsed: Long,
        totalTimeInForeground: Long, lastTimeVisible: Long?, totalTimeVisible: Long?,
        lastTimeForegroundServiceUsed: Long?, totalTimeForegroundServiceUsed: Long?
    ) {
        val values = ContentValues().apply {
            put("packageName", packageName)
            put("firstTimeStamp", firstTimeStamp)
            put("lastTimeStamp", lastTimeStamp)
            put("lastTimeUsed", lastTimeUsed)
            put("totalTimeInForeground", totalTimeInForeground)
            put("lastTimeVisible", lastTimeVisible)
            put("totalTimeVisible", totalTimeVisible)
            put("lastTimeForegroundServiceUsed", lastTimeForegroundServiceUsed)
            put("totalTimeForegroundServiceUsed", totalTimeForegroundServiceUsed)
            put("sync_status", 0)
        }
        writableDatabase.insert(TABLE_RAW_USAGE_STATS, null, values)
    }

    fun insertRawSystemEvent(timestamp: Long, eventType: String, value: String? = null, extras: String? = null) {
        val values = ContentValues().apply {
            put("timestamp", timestamp)
            put("event_type", eventType)
            put("value", value)
            put("extras", extras)
            put("source", "broadcast_receiver")
            put("sync_status", 0)
        }
        writableDatabase.insert(TABLE_RAW_SYSTEM_EVENTS, null, values)
    }
}