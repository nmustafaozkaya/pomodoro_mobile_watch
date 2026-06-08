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
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private val SESSION_UPDATE_CHANNEL = "com.pomodoro.phone/session_updates"
    private val WEAR_BRIDGE_CHANNEL = "com.pomodoro.phone/wear"
    private var eventSink: EventChannel.EventSink? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val sessionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val totalWorkMinutes = intent?.getIntExtra("totalWorkMinutes", 0) ?: 0
            val sessionMinutes = intent?.getIntExtra("sessionMinutes", 0) ?: 0
            val source = intent?.getStringExtra("source") ?: "phone"
            val completed = intent?.getBooleanExtra("isCompleted", false) ?: false
            val isReset = intent?.getBooleanExtra("isReset", false) ?: false
            val timestamp = intent?.getLongExtra("timestamp", 0L) ?: 0L

            eventSink?.success(
                mapOf(
                    "totalWorkMinutes" to totalWorkMinutes,
                    "sessionMinutes" to sessionMinutes,
                    "source" to source,
                    "isCompleted" to completed,
                    "isReset" to isReset,
                    "timestamp" to timestamp,
                ),
            )
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val filter = IntentFilter("com.nmodev.pomodoro.SESSION_UPDATE")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.registerReceiver(
                this,
                sessionReceiver,
                filter,
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
        } else {
            registerReceiver(sessionReceiver, filter)
        }

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

            MethodChannel(messenger, WEAR_BRIDGE_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncPhoneWorkSession" -> {
                        val minutes = (call.arguments as? Map<*, *>)?.get("minutes") as? Int ?: 0
                        scope.launch {
                            withContext(Dispatchers.IO) {
                                PhoneWearSync.addPhoneSessionAndSyncWatch(applicationContext, minutes)
                            }
                            result.success(null)
                        }
                    }
                    "pushTimerSettings" -> {
                        val args = call.arguments as? Map<*, *> ?: run {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        val selected = (args["selectedMinutes"] as? Number)?.toInt() ?: 25
                        val brk = (args["breakMinutes"] as? Number)?.toInt() ?: 5
                        val lang = args["language"] as? String ?: "en"
                        scope.launch {
                            withContext(Dispatchers.IO) {
                                PhoneWearSync.pushTimerSettingsToWatch(
                                    applicationContext,
                                    selected,
                                    brk,
                                    lang,
                                )
                            }
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

            // Wear APK değil phone APK yüklüyse (ör. yanlış flavor), Dart WearApp yine açılır;
            // bu stub'lar MissingPluginException önler. Telefon–saat senkronu için `--flavor wear` kullanın.
            val wearFlutterData = "com.pomodoro.wear/data"
            MethodChannel(messenger, wearFlutterData).setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSession" -> result.success(false)
                    "getTotalMinutes" -> result.success(0)
                    "getSettingsFromDataLayer" -> result.success("{}")
                    else -> result.notImplemented()
                }
            }
            EventChannel(messenger, "com.pomodoro.wear/stats").setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {}
                    override fun onCancel(arguments: Any?) {}
                },
            )
            EventChannel(messenger, "com.pomodoro.wear/settings").setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {}
                    override fun onCancel(arguments: Any?) {}
                },
            )
            EventChannel(messenger, "com.pomodoro.wear/rotary").setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {}
                    override fun onCancel(arguments: Any?) {}
                },
            )
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(sessionReceiver)
        } catch (_: Exception) {
        }
    }
}
