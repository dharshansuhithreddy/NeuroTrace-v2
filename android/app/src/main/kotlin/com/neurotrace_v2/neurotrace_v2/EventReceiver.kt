package com.neurotrace_v2.neurotrace_v2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

class EventReceiver : BroadcastReceiver() {
    private val TAG = "NeuroTrace_EventReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val timestamp = System.currentTimeMillis()
        val dbHelper = DatabaseHelper(context)

        when (action) {
            Intent.ACTION_SCREEN_ON -> {
                Log.d(TAG, "Hardware Event: Screen ON at $timestamp")
                dbHelper.insertUsageEvent(timestamp, "SCREEN_ON")
                // Note: We don't start polling yet. User hasn't unlocked the phone.
            }
            Intent.ACTION_SCREEN_OFF -> {
                Log.d(TAG, "Hardware Event: Screen OFF at $timestamp")
                dbHelper.insertUsageEvent(timestamp, "SCREEN_OFF")

                // POWER MANAGEMENT: Command the service to immediately pause the polling loop
                val serviceIntent = Intent(context, CollectionService::class.java).apply {
                    this.action = CollectionService.ACTION_STOP_POLLING
                }
                ContextCompat.startForegroundService(context, serviceIntent)
            }
            Intent.ACTION_USER_PRESENT -> {
                Log.d(TAG, "Hardware Event: Device Unlocked at $timestamp")
                dbHelper.insertUsageEvent(timestamp, "DEVICE_UNLOCK")

                // POWER MANAGEMENT: Command the service to resume the polling loop
                val serviceIntent = Intent(context, CollectionService::class.java).apply {
                    this.action = CollectionService.ACTION_START_POLLING
                }
                ContextCompat.startForegroundService(context, serviceIntent)
            }
        }
    }
}