package com.nmodev.pomodoro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val SESSION_UPDATE_CHANNEL = "com.pomodoro.phone/session_updates"
    private var eventSink: EventChannel.EventSink? = null

    private val sessionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val minutes = intent?.getIntExtra("totalWorkMinutes", 0) ?: 0
            val completed = intent?.getBooleanExtra("isCompleted", false) ?: false
            val isReset = intent?.getBooleanExtra("isReset", false) ?: false
            val timestamp = intent?.getLongExtra("timestamp", 0L) ?: 0L

            // Flutter'a gönder
            eventSink?.success(mapOf(
                "totalWorkMinutes" to minutes,
                "isCompleted" to completed,
                "isReset" to isReset,
                "timestamp" to timestamp
            ))
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Broadcast receiver kaydet (Android 13+ uyumluluğu için)
        val filter = IntentFilter("com.nmodev.pomodoro.SESSION_UPDATE")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ (API 33+) için RECEIVER_NOT_EXPORTED flag'i gerekli
            ContextCompat.registerReceiver(
                this,
                sessionReceiver,
                filter,
                ContextCompat.RECEIVER_NOT_EXPORTED
            )
        } else {
            // Android 12 ve öncesi için eski yöntem
            registerReceiver(sessionReceiver, filter)
        }

        // Flutter Event Channel
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            EventChannel(messenger, SESSION_UPDATE_CHANNEL)
                .setStreamHandler(object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        eventSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        eventSink = null
                    }
                })
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(sessionReceiver)
        } catch (e: Exception) {
            // Receiver zaten unregister edilmiş olabilir
        }
    }
}
