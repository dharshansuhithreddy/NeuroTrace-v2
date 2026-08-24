package com.neurotrace_v2.neurotrace_v2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class EventReceiver : BroadcastReceiver() {
    private val TAG = "NeuroTrace_EventReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val timestamp = System.currentTimeMillis()
        val dbHelper = DatabaseHelper(context)

        Log.d(TAG, "Raw Hardware Broadcast: $action at $timestamp")

        when (action) {
            Intent.ACTION_SCREEN_ON -> dbHelper.insertRawSystemEvent(timestamp, "SCREEN_ON")
            Intent.ACTION_SCREEN_OFF -> dbHelper.insertRawSystemEvent(timestamp, "SCREEN_OFF")
            Intent.ACTION_USER_PRESENT -> dbHelper.insertRawSystemEvent(timestamp, "DEVICE_UNLOCK")
            else -> dbHelper.insertRawSystemEvent(timestamp, action) // Fallback for any other events
        }
    }
}