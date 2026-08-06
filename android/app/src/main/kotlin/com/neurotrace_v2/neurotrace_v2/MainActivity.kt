package com.neurotrace_v2.neurotrace_v2

import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.HashMap

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.neurotrace_v2.telemetry"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    try {
                        val intent = Intent(this, CollectionService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_FAILED", "Could not start collection service", e.message)
                    }
                }

                "getOperationalStats" -> {
                    try {
                        val dbHelper = DatabaseHelper(this)
                        val db = dbHelper.readableDatabase

                        val totalCursor = db.rawQuery("SELECT COUNT(*) FROM ${DatabaseHelper.TABLE_DEVICE_EVENTS}", null)
                        var totalEvents = 0
                        if (totalCursor.moveToFirst()) {
                            totalEvents = totalCursor.getInt(0)
                        }
                        totalCursor.close()

                        val validatedCursor = db.rawQuery(
                            "SELECT COUNT(*) FROM ${DatabaseHelper.TABLE_DEVICE_EVENTS} WHERE event_type NOT IN ('SCREEN_ON', 'SCREEN_OFF', 'DEVICE_UNLOCK')",
                            null
                        )
                        var validatedSessions = 0
                        if (validatedCursor.moveToFirst()) {
                            validatedSessions = validatedCursor.getInt(0)
                        }
                        validatedCursor.close()
                        db.close()

                        val isServiceRunning = isCollectionServiceRunning(CollectionService::class.java)

                        val statsMap = HashMap<String, Any>()
                        statsMap["total_events"] = totalEvents
                        statsMap["validated_sessions"] = validatedSessions
                        statsMap["is_service_running"] = isServiceRunning

                        result.success(statsMap)
                    } catch (e: Exception) {
                        result.error("DB_METRIC_ERROR", "Failed to compute telemetry row indices: ${e.message}", null)
                    }
                }

                "triggerCsvExport" -> {
                    try {
                        val dbHelper = DatabaseHelper(this)
                        val resultPath = dbHelper.exportDatabaseToCSV(this)
                        result.success(resultPath)
                    } catch (e: Exception) {
                        result.error("EXPORT_FAILED", "Telemetry dataset compilation aborted: ${e.message}", null)
                    }
                }

                "fetchLocalData" -> {
                    try {
                        val dbHelper = DatabaseHelper(this)
                        val db = dbHelper.readableDatabase
                        val cursor = db.query(DatabaseHelper.TABLE_DEVICE_EVENTS, null, null, null, null, null, "timestamp DESC")
                        val usageList = ArrayList<Map<String, Any>>()

                        while (cursor.moveToNext()) {
                            val timestamp = cursor.getLong(cursor.getColumnIndexOrThrow("timestamp"))
                            val packageName = cursor.getString(cursor.getColumnIndexOrThrow("event_type"))
                            val map = HashMap<String, Any>()
                            map["timestamp"] = timestamp
                            map["packageName"] = packageName
                            usageList.add(map)
                        }
                        cursor.close()
                        db.close()
                        result.success(usageList)
                    } catch (e: Exception) {
                        result.error("DB_ERROR", "Failed to fetch structured list: ${e.message}", null)
                    }
                }

                // --- Fetch only pending items for Firestore Sync ---
                "fetchPendingLocalData" -> {
                    try {
                        val dbHelper = DatabaseHelper(this)
                        val db = dbHelper.readableDatabase

                        val cursor = db.rawQuery(
                            "SELECT id, timestamp, event_type FROM ${DatabaseHelper.TABLE_DEVICE_EVENTS} WHERE sync_status = 0 OR (sync_status = 2 AND retry_count < 5) ORDER BY timestamp ASC LIMIT 400",
                            null
                        )

                        val usageList = ArrayList<Map<String, Any>>()
                        while (cursor.moveToNext()) {
                            val map = HashMap<String, Any>()
                            map["id"] = cursor.getInt(cursor.getColumnIndexOrThrow("id")).toString()
                            map["timestamp"] = cursor.getLong(cursor.getColumnIndexOrThrow("timestamp"))
                            map["packageName"] = cursor.getString(cursor.getColumnIndexOrThrow("event_type"))
                            usageList.add(map)
                        }
                        cursor.close()
                        db.close()
                        result.success(usageList)
                    } catch (e: Exception) {
                        result.error("DB_FETCH_ERROR", "Failed to retrieve pending telemetry: ${e.message}", null)
                    }
                }

                // --- Atomic updates to SQLite after Firebase Sync attempt ---
                "updateSyncStatus" -> {
                    try {
                        val ids = call.argument<List<String>>("ids")
                        val status = call.argument<Int>("status") ?: 0 // 1 = SYNCED, 2 = FAILED

                        if (ids == null || ids.isEmpty()) {
                            result.success(true)
                            return@setMethodCallHandler
                        }

                        val dbHelper = DatabaseHelper(this)
                        val db = dbHelper.writableDatabase

                        db.beginTransaction()
                        try {
                            if (status == 1) {
                                val stmt = db.compileStatement("UPDATE ${DatabaseHelper.TABLE_DEVICE_EVENTS} SET sync_status = 1 WHERE id = ?")
                                for (idStr in ids) {
                                    val idLong = idStr.toLongOrNull()
                                    if (idLong != null) {
                                        stmt.bindLong(1, idLong)
                                        stmt.execute()
                                    }
                                }
                            } else {
                                val currentEpoch = System.currentTimeMillis()
                                val stmt = db.compileStatement(
                                    "UPDATE ${DatabaseHelper.TABLE_DEVICE_EVENTS} SET sync_status = 2, retry_count = retry_count + 1, last_sync_attempt = ? WHERE id = ?"
                                )
                                for (idStr in ids) {
                                    val idLong = idStr.toLongOrNull()
                                    if (idLong != null) {
                                        stmt.bindLong(1, currentEpoch)
                                        stmt.bindLong(2, idLong)
                                        stmt.execute()
                                    }
                                }
                            }
                            db.setTransactionSuccessful()
                            result.success(true)
                        } finally {
                            db.endTransaction()
                            db.close()
                        }
                    } catch (e: Exception) {
                        result.error("DB_UPDATE_ERROR", "Transactional status alteration failed: ${e.message}", null)
                    }
                }

                "openUsageAccessSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open settings frame", e.message)
                    }
                }

                "isBatteryOptimizationIgnored" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isIgnored = pm.isIgnoringBatteryOptimizations(packageName)
                    result.success(isIgnored)
                }

                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Could not request battery exemption target", e.message)
                    }
                }

                "requestAutoStartPermission" -> {
                    try {
                        val manufacturer = android.os.Build.MANUFACTURER.lowercase()
                        val intent = Intent()

                        when {
                            manufacturer.contains("xiaomi") || manufacturer.contains("poco") || manufacturer.contains("redmi") -> {
                                intent.component = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                            }
                            manufacturer.contains("oppo") || manufacturer.contains("realme") || manufacturer.contains("oneplus") -> {
                                intent.component = ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")
                            }
                            manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> {
                                intent.component = ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                            }
                            manufacturer.contains("infinix") || manufacturer.contains("tecno") || manufacturer.contains("itel") -> {
                                intent.component = ComponentName("com.transsion.phonemaster", "com.cyin.himgr.autostart.AutoStartActivity")
                            }
                            manufacturer.contains("asus") -> {
                                intent.component = ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity")
                            }
                            else -> {
                                result.success("No custom auto-start configurations required for $manufacturer")
                                return@setMethodCallHandler
                            }
                        }

                        try {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success("Auto-Start Intent Launched for $manufacturer")
                        } catch (e: Exception) {
                            result.success("Auto-Start settings missing on this specific $manufacturer model structure")
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Could not open custom platform systems management", e.message)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isCollectionServiceRunning(serviceClass: Class<*>): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in manager.getRunningServices(Integer.MAX_VALUE)) {
            if (serviceClass.name == service.service.className) {
                return true
            }
        }
        return false
    }
}