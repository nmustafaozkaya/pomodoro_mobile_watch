package com.nmodev.pomodoro

import android.net.Uri
import android.os.Bundle
import android.view.InputDevice
import android.view.MotionEvent
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.pomodoro.wear/data"
    private val STATS_CHANNEL = "com.pomodoro.wear/stats"
    private val SETTINGS_CHANNEL = "com.pomodoro.wear/settings"
    private val ROTARY_CHANNEL = "com.pomodoro.wear/rotary"

    private lateinit var dataClient: DataClient
    private val scopeJob: Job = SupervisorJob()
    private val scope = CoroutineScope(scopeJob + Dispatchers.Main)
    private var statsSink: EventChannel.EventSink? = null
    private var settingsSink: EventChannel.EventSink? = null
    private var rotarySink: EventChannel.EventSink? = null

    private var dataListener: DataClient.OnDataChangedListener? = null
    private var dataListenerAttached = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        dataClient = Wearable.getDataClient(this)
        attachDataLayerListener()

        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSession" -> {
                        val data = call.arguments as? Map<*, *>
                        if (data != null) {
                            scope.launch {
                                val success = sendSessionToPhone(data)
                                result.success(success)
                            }
                        } else {
                            result.error("INVALID_DATA", "Data is null", null)
                        }
                    }
                    "getTotalMinutes" -> {
                        scope.launch {
                            val total = requestTotalFromPhone()
                            result.success(total)
                        }
                    }
                    "getSettingsFromDataLayer" -> {
                        scope.launch {
                            val json = readSettingsFromDataLayer()
                            result.success(json)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

            EventChannel(messenger, STATS_CHANNEL).setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        statsSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        statsSink = null
                    }
                },
            )

            EventChannel(messenger, SETTINGS_CHANNEL).setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        settingsSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        settingsSink = null
                    }
                },
            )

            // Fiziksel taç / (destekleyen cihazlarda) bezel kaydırması → Flutter PointerScroll ile aynı eksende iletilir.
            EventChannel(messenger, ROTARY_CHANNEL).setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        rotarySink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        rotarySink = null
                    }
                },
            )
        }
    }

    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_SCROLL) {
            val scroll = event.getAxisValue(MotionEvent.AXIS_SCROLL)
            if (scroll != 0f &&
                (event.source and InputDevice.SOURCE_ROTARY_ENCODER) == InputDevice.SOURCE_ROTARY_ENCODER
            ) {
                // Flutter’daki PointerScrollEvent.scrollDelta.dy ile uyumlu yön (ileri = pozitif).
                rotarySink?.success((-scroll).toDouble())
                return true
            }
        }
        return super.dispatchGenericMotionEvent(event)
    }

    private fun attachDataLayerListener() {
        if (dataListenerAttached) return
        dataListener = DataClient.OnDataChangedListener { buffer ->
            try {
                for (i in 0 until buffer.count) {
                    val event = buffer.get(i)
                    if (event.type != DataEvent.TYPE_CHANGED) continue
                    val path = event.dataItem.uri.path ?: continue
                    when (path) {
                        "/total_stats" -> {
                            val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap
                            val totalMinutes = dataMap.getInt("totalMinutes", 0)
                            scope.launch(Dispatchers.Main) {
                                statsSink?.success(totalMinutes)
                            }
                        }
                        "/pomodoro_settings" -> {
                            val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap
                            val payload = mapOf(
                                "selectedMinutes" to dataMap.getInt("selectedMinutes", 25),
                                "breakMinutes" to dataMap.getInt("breakMinutes", 5),
                                "language" to (dataMap.getString("language", "en") ?: "en"),
                            )
                            scope.launch(Dispatchers.Main) {
                                settingsSink?.success(payload)
                            }
                        }
                    }
                }
            } finally {
                buffer.release()
            }
        }
        dataClient.addListener(dataListener!!)
        dataListenerAttached = true
    }

    private suspend fun sendSessionToPhone(data: Map<*, *>): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val putDataReq = PutDataMapRequest.create("/pomodoro_session").apply {
                    dataMap.putInt("minutes", (data["minutes"] as? Number)?.toInt() ?: 0)
                    dataMap.putLong(
                        "timestamp",
                        (data["timestamp"] as? Number)?.toLong() ?: System.currentTimeMillis(),
                    )
                    dataMap.putString("source", "watch")
                }.asPutDataRequest().setUrgent()

                Tasks.await(dataClient.putDataItem(putDataReq))
                android.util.Log.d("WearDataLayer", "Session sent successfully")
                true
            } catch (e: Exception) {
                android.util.Log.e("WearDataLayer", "Send failed: ${e.message}", e)
                false
            }
        }
    }

    private suspend fun requestTotalFromPhone(): Int {
        return withContext(Dispatchers.IO) {
            try {
                val messageClient = Wearable.getMessageClient(this@MainActivity)
                val nodeClient = Wearable.getNodeClient(this@MainActivity)
                val nodes = Tasks.await(nodeClient.connectedNodes)

                if (nodes.isNotEmpty()) {
                    Tasks.await(
                        messageClient.sendMessage(
                            nodes.first().id,
                            "/request_total",
                            ByteArray(0),
                        ),
                    )

                    delay(2000)
                    val dataItems = Tasks.await(
                        dataClient.getDataItems(Uri.parse("wear://*/total_stats")),
                    )

                    dataItems.firstOrNull()?.let { item ->
                        DataMapItem.fromDataItem(item).dataMap.getInt("totalMinutes", 0)
                    } ?: 0
                } else {
                    0
                }
            } catch (e: Exception) {
                android.util.Log.e("WearDataLayer", "Request total failed: ${e.message}", e)
                0
            }
        }
    }

    private suspend fun readSettingsFromDataLayer(): String {
        return withContext(Dispatchers.IO) {
            try {
                val items = Tasks.await(
                    dataClient.getDataItems(Uri.parse("wear://*/pomodoro_settings")),
                )
                val item = items.firstOrNull() ?: return@withContext "{}"
                val dm = DataMapItem.fromDataItem(item).dataMap
                val sel = dm.getInt("selectedMinutes", 25)
                JSONObject().apply {
                    put("selectedMinutes", sel)
                    put("breakMinutes", dm.getInt("breakMinutes", 5))
                    put("language", dm.getString("language", "en") ?: "en")
                    put("durationSeconds", sel * 60)
                }.toString()
            } catch (e: Exception) {
                "{}"
            }
        }
    }

    override fun onDestroy() {
        if (dataListenerAttached) {
            dataListener?.let { dataClient.removeListener(it) }
            dataListenerAttached = false
            dataListener = null
        }
        scopeJob.cancel()
        super.onDestroy()
    }
}
