package com.neurotrace_v2.neurotrace_v2

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

class CollectionService : Service() {
    private val TAG = "NeuroTrace_Collector"
    private val INTERVAL = 60000L // 1 minute
    private val handler = Handler(Looper.getMainLooper())

    private lateinit var dbHelper: DatabaseHelper
    private var isPolling = false

    private val collectionRunnable = object : Runnable {
        override fun run() {
            collectRawTelemetry()
            handler.postDelayed(this, INTERVAL)
        }
    }

    override fun onCreate() {
        super.onCreate()
        dbHelper = DatabaseHelper(this)
        Log.d(TAG, "Raw CollectionService Created.")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(1, createNotification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, createNotification())
        }

        // Always ensure polling is running for continuous raw collection
        if (!isPolling) {
            isPolling = true
            handler.post(collectionRunnable)
            Log.d(TAG, "Continuous Raw Polling STARTED.")
        }

        return START_STICKY
    }

    private fun collectRawTelemetry() {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
        if (usageStatsManager == null) {
            Log.e(TAG, "UsageStatsManager is null")
            return
        }

        val endTime = System.currentTimeMillis()
        val startTime = endTime - INTERVAL

        // 1. Collect Raw Events (No filtering, exact replication of OS data)
        val events = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            dbHelper.insertRawUsageEvent(
                packageName = event.packageName,
                className = event.className,
                eventType = event.eventType,
                timestamp = event.timeStamp,

                // Unresolved fields explicitly nulled to ensure compilation
                instanceId = null,
                taskRootPackageName = null,
                taskRootClassName = null,
                notificationChannelId = null,
                locusId = null,

                // Maintained backward-compatible fields
                standbyBucket = if (Build.VERSION.SDK_INT >= 28) event.appStandbyBucket else null,
                configuration = if (Build.VERSION.SDK_INT >= 21) event.configuration?.toString() else null,
                shortcutId = if (Build.VERSION.SDK_INT >= 28) event.shortcutId else null
            )
        }

        // 2. Collect UsageStats Aggregates (No launcher/package filtering)
        val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
        for (stat in stats) {
            dbHelper.insertRawUsageStat(
                packageName = stat.packageName,
                firstTimeStamp = stat.firstTimeStamp,
                lastTimeStamp = stat.lastTimeStamp,
                lastTimeUsed = stat.lastTimeUsed,
                totalTimeInForeground = stat.totalTimeInForeground,
                lastTimeVisible = if (Build.VERSION.SDK_INT >= 29) stat.lastTimeVisible else null,
                totalTimeVisible = if (Build.VERSION.SDK_INT >= 29) stat.totalTimeVisible else null,
                lastTimeForegroundServiceUsed = if (Build.VERSION.SDK_INT >= 29) stat.lastTimeForegroundServiceUsed else null,
                totalTimeForegroundServiceUsed = if (Build.VERSION.SDK_INT >= 29) stat.totalTimeForegroundServiceUsed else null
            )
        }
    }

    private fun createNotification(): Notification {
        val channelId = "neurotrace_service_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Data Collection", NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("NeuroTrace Active")
            .setContentText("Collecting raw behavioral telemetry.")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        isPolling = false
        handler.removeCallbacks(collectionRunnable)
        dbHelper.close()
        Log.d(TAG, "CollectionService Destroyed.")
    }

    override fun onBind(intent: Intent?): IBinder? = null
}