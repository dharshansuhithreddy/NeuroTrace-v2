package com.neurotrace_v2.neurotrace_v2

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.os.Environment
import android.util.Log
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    private val appContext = context.applicationContext

    companion object {
        // MATCH FLUTTER EXACTLY
        private const val DATABASE_NAME = "neurotrace_v2.db"
        private const val DATABASE_VERSION = 3

        // Target Flutter's existing device_events table instead of a ghost table
        const val TABLE_DEVICE_EVENTS = "device_events"
    }

    override fun onCreate(db: SQLiteDatabase) {
        // If the background service starts before Flutter, it must create the EXACT Flutter schemas.
        db.execSQL("""
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
        """)
        db.execSQL("""
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
        """)
        db.execSQL("""
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
        """)
        db.execSQL("""
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
        """)
        Log.d("NeuroTrace_DB", "Native DB Created matching Flutter Schema.")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // Allow Flutter to be the master controller of complex schema upgrades
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        // CRITICAL: Ensure native writes do not lock the database when Flutter reads
        db.enableWriteAheadLogging()
    }

    // Function signature kept identical so CollectionService doesn't break
    fun insertUsageEvent(timestamp: Long, packageName: String) {
        val db = this.writableDatabase

        // Magically extract the participant ID directly from Flutter's native prefs file!
        val prefs = appContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val researchId = prefs.getString("flutter.research_id", "Unknown") ?: "Unknown"

        val contentValues = ContentValues().apply {
            // DO NOT insert 'id' -> SQLite will autoincrement it natively
            put("research_id", researchId)
            put("event_type", packageName) // Store package name in the event_type column
            put("timestamp", timestamp)
            put("is_synced", 0)
            put("sync_status", 0)
            put("retry_count", 0)
            put("last_sync_attempt", 0)
        }

        val result = db.insert(TABLE_DEVICE_EVENTS, null, contentValues)
        if (result == -1L) {
            Log.e("NeuroTrace_DB", "Failed to insert into device_events")
        } else {
            Log.d("NeuroTrace_DB", "Native Insert Success: $packageName at $timestamp")
        }
    }

    fun exportDatabaseToCSV(context: Context): String {
        val db = this.readableDatabase
        val cursor = db.rawQuery("SELECT * FROM $TABLE_DEVICE_EVENTS ORDER BY timestamp ASC", null)

        val exportDir = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
        if (exportDir?.exists() == false) {
            exportDir.mkdirs()
        }

        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val file = File(exportDir, "NeuroTrace_Data_$timeStamp.csv")

        return try {
            file.createNewFile()
            val csvWrite = FileWriter(file)
            csvWrite.append("ID,Research_ID,Event_Type,Timestamp_ms,Readable_Time,Sync_Status\n")

            if (cursor.moveToFirst()) {
                do {
                    val id = cursor.getInt(cursor.getColumnIndexOrThrow("id"))
                    val resId = cursor.getString(cursor.getColumnIndexOrThrow("research_id"))
                    val eventType = cursor.getString(cursor.getColumnIndexOrThrow("event_type"))
                    val timestamp = cursor.getLong(cursor.getColumnIndexOrThrow("timestamp"))
                    val syncStatus = cursor.getInt(cursor.getColumnIndexOrThrow("sync_status"))

                    val readableTime = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date(timestamp))

                    csvWrite.append("$id,$resId,$eventType,$timestamp,$readableTime,$syncStatus\n")
                } while (cursor.moveToNext())
            }

            csvWrite.flush()
            csvWrite.close()
            cursor.close()

            "Success! File saved to: ${file.absolutePath}"
        } catch (e: Exception) {
            cursor.close()
            "Export Failed: ${e.message}"
        }
    }
}