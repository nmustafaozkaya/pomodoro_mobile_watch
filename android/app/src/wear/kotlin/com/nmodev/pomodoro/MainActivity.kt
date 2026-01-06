package com.nmodev.pomodoro

import android.net.Uri
import android.os.Bundle
import com.google.android.gms.wearable.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import com.google.android.gms.tasks.Tasks

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.pomodoro.wear/data"
    private val EVENT_CHANNEL = "com.pomodoro.wear/stats"
    private lateinit var dataClient: DataClient
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Data Client başlat
        dataClient = Wearable.getDataClient(this)
        
        // Flutter Method Channel
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
                    "getUserId" -> {
                        scope.launch {
                            val userId = requestUserIdFromPhone()
                            result.success(userId)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
            
            // Event Channel - Telefondan güncellemeleri al
            EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        eventSink = events
                        startListeningToPhone()
                    }
                    
                    override fun onCancel(arguments: Any?) {
                        eventSink = null
                    }
                }
            )
        }
    }

    private suspend fun sendSessionToPhone(data: Map<*, *>): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val putDataReq = PutDataMapRequest.create("/pomodoro_session").apply {
                    dataMap.putInt("minutes", (data["minutes"] as? Number)?.toInt() ?: 0)
                    dataMap.putLong("timestamp", (data["timestamp"] as? Number)?.toLong() ?: System.currentTimeMillis())
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
                // Telefona "toplam gönder" mesajı
                val messageClient = Wearable.getMessageClient(this@MainActivity)
                val nodeClient = Wearable.getNodeClient(this@MainActivity)
                val nodes = Tasks.await(nodeClient.connectedNodes)
                
                if (nodes.isNotEmpty()) {
                    Tasks.await(
                        messageClient.sendMessage(
                            nodes.first().id,
                            "/request_total",
                            ByteArray(0)
                        )
                    )
                    
                    // Yanıt bekle
                    delay(2000)
                    val dataItems = Tasks.await(
                        dataClient.getDataItems(Uri.parse("wear://*/total_stats"))
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
    
    private fun startListeningToPhone() {
        scope.launch(Dispatchers.IO) {
            dataClient.addListener { dataEvents ->
                dataEvents.forEach { event ->
                    if (event.type == DataEvent.TYPE_CHANGED) {
                        val item = event.dataItem
                        if (item.uri.path == "/total_stats") {
                            val dataMap = DataMapItem.fromDataItem(item).dataMap
                            val totalMinutes = dataMap.getInt("totalMinutes", 0)
                            
                            // Flutter'a gönder
                            scope.launch(Dispatchers.Main) {
                                eventSink?.success(totalMinutes)
                            }
                        }
                    }
                }
            }
        }
    }

    private suspend fun requestUserIdFromPhone(): String {
        return withContext(Dispatchers.IO) {
            try {
                // Telefona mesaj gönder
                val nodeClient = Wearable.getNodeClient(this@MainActivity)
                val nodes = Tasks.await(nodeClient.connectedNodes)
                
                if (nodes.isNotEmpty()) {
                    val messageClient = Wearable.getMessageClient(this@MainActivity)
                    val sendTask = messageClient.sendMessage(
                        nodes.first().id,
                        "/request_user_id",
                        ByteArray(0)
                    )
                    Tasks.await(sendTask)
                    
                    // Yanıt bekle (DataClient üzerinden)
                    delay(2000) // Yanıt için bekle
                    val dataItems = Tasks.await(
                        dataClient.getDataItems(Uri.parse("wear://*/user_id"))
                    )
                    
                    dataItems.firstOrNull()?.let { item ->
                        DataMapItem.fromDataItem(item).dataMap.getString("userId") ?: ""
                    } ?: ""
                } else {
                    ""
                }
            } catch (e: Exception) {
                android.util.Log.e("WearDataLayer", "getUserId failed: ${e.message}", e)
                ""
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}
