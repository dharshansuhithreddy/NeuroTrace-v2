package com.neurotrace_v2.neurotrace_v2

import android.app.*
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

class CollectionService : Service() {
    private val TAG = "NeuroTrace_Collector"
    private val INTERVAL = 60000L // 1 minute
    private val handler = Handler(Looper.getMainLooper())

    private lateinit var dbHelper: DatabaseHelper
    private lateinit var powerManager: PowerManager
    private lateinit var eventReceiver: EventReceiver

    private var isPolling = false

    companion object {
        const val ACTION_START_POLLING = "com.neurotrace_v2.ACTION_START_POLLING"
        const val ACTION_STOP_POLLING = "com.neurotrace_v2.ACTION_STOP_POLLING"
    }

    private val collectionRunnable = object : Runnable {
        override fun run() {
            validateAndCollectUsage()
            handler.postDelayed(this, INTERVAL)
        }
    }

    override fun onCreate() {
        super.onCreate()
        dbHelper = DatabaseHelper(this)
        powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager

        eventReceiver = EventReceiver()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(eventReceiver, filter)
        Log.d(TAG, "CollectionService Created and Receiver Registered.")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Enforce Android 8+ requirement, while satisfying targetSDK 36 strictness dynamically
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                1,
                createNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(1, createNotification())
        }

        when (intent?.action) {
            ACTION_STOP_POLLING -> {
                Log.d(TAG, "Command Received: STOP_POLLING")
                stopPolling()
            }
            ACTION_START_POLLING -> {
                Log.d(TAG, "Command Received: START_POLLING")
                startPolling()
            }
            else -> {
                Log.d(TAG, "Service started normally, initiating collection loop.")
                startPolling()
            }
        }

        return START_STICKY
    }

    private fun startPolling() {
        if (!isPolling) {
            isPolling = true
            handler.post(collectionRunnable)
            Log.d(TAG, "Validation Engine: Foreground polling loop STARTED/RESUMED.")
        }
    }

    private fun stopPolling() {
        if (isPolling) {
            isPolling = false
            handler.removeCallbacks(collectionRunnable)
            Log.d(TAG, "Validation Engine: Foreground polling loop STOPPED. CPU can sleep.")
        }
    }

    private fun validateAndCollectUsage() {
        val isScreenInteractive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
            powerManager.isInteractive
        } else {
            @Suppress("DEPRECATION")
            powerManager.isScreenOn
        }

        if (!isScreenInteractive) {
            Log.d(TAG, "Validation Engine: Screen is OFF. Skipping application session tracking.")
            return
        }

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
        if (usageStatsManager == null) {
            Log.e(TAG, "UsageStatsManager is null")
            return
        }

        val endTime = System.currentTimeMillis()
        val startTime = endTime - INTERVAL

        val stats = usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)

        for (stat in stats) {
            if (stat.lastTimeUsed > startTime) {
                val pkg = stat.packageName

                if (pkg.contains("launcher") || pkg.contains("nexuslauncher") || pkg == packageName) {
                    continue
                }

                Log.d(TAG, "Validated Session Saved: $pkg")
                dbHelper.insertUsageEvent(stat.lastTimeUsed, pkg)
            }
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
            .setContentText("Collecting behavioral data for research.")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopPolling()
        dbHelper.close()

        try {
            unregisterReceiver(eventReceiver)
        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "Receiver already unregistered")
        }
        Log.d(TAG, "CollectionService Destroyed.")
    }

    override fun onBind(intent: Intent?): IBinder? = null
}