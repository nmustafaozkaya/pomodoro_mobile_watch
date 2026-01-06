package com.nmodev.pomodoro

import android.content.Intent
import android.util.Log
import com.google.android.gms.wearable.*
import com.google.android.gms.tasks.Tasks
import kotlinx.coroutines.*
import android.content.Context
import android.content.SharedPreferences

class DataLayerListenerService : WearableListenerService() {
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private val TAG = "DataLayerListener"

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        dataEvents.forEach { event ->
            if (event.type == DataEvent.TYPE_CHANGED) {
                val item = event.dataItem
                
                when (item.uri.path) {
                    "/pomodoro_session" -> {
                        handlePomodoroSession(item)
                    }
                }
            }
        }
    }

    private fun handlePomodoroSession(item: DataItem) {
        val dataMap = DataMapItem.fromDataItem(item).dataMap
        val minutes = dataMap.getInt("minutes", 0)

        Log.d(TAG, "Received session: $minutes minutes")

        // Veritabanına kaydet
        scope.launch {
            saveSessionToDatabase(minutes)
            
            // YENİ TOPLAMI HESAPLA
            val newTotal = calculateTotalMinutes()
            
            // Saate gönder
            sendTotalToWatch(newTotal)
        }
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        when (messageEvent.path) {
            "/request_user_id" -> {
                scope.launch {
                    sendUserIdToWatch(messageEvent.sourceNodeId)
                }
            }
            "/request_total" -> {
                scope.launch {
                    val total = calculateTotalMinutes()
                    sendTotalToWatch(total)
                }
            }
        }
    }

    private suspend fun sendUserIdToWatch(nodeId: String) {
        withContext(Dispatchers.IO) {
            try {
                val userId = getUserIdFromPreferences()
                
                val putDataReq = PutDataMapRequest.create("/user_id").apply {
                    dataMap.putString("userId", userId)
                    dataMap.putLong("timestamp", System.currentTimeMillis())
                }.asPutDataRequest()

                val dataClient = Wearable.getDataClient(this@DataLayerListenerService)
                Tasks.await(dataClient.putDataItem(putDataReq))
                
                Log.d(TAG, "User ID sent to watch: $userId")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send user ID: ${e.message}")
            }
        }
    }

    private fun getUserIdFromPreferences(): String {
        val prefs = getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
        return prefs.getString("user_id", "") ?: ""
    }

    private suspend fun saveSessionToDatabase(minutes: Int) {
        withContext(Dispatchers.IO) {
            val prefs = getSharedPreferences("pomodoro_work_data", Context.MODE_PRIVATE)
            val currentTotal = prefs.getInt("totalWorkMinutes", 0)
            prefs.edit()
                .putInt("totalWorkMinutes", currentTotal + minutes)
                .apply()
        }
    }
    
    private suspend fun calculateTotalMinutes(): Int {
        return withContext(Dispatchers.IO) {
            val prefs = getSharedPreferences("pomodoro_work_data", Context.MODE_PRIVATE)
            prefs.getInt("totalWorkMinutes", 0)
        }
    }
    
    private suspend fun sendTotalToWatch(totalMinutes: Int) {
        withContext(Dispatchers.IO) {
            try {
                val putDataReq = PutDataMapRequest.create("/total_stats").apply {
                    dataMap.putInt("totalMinutes", totalMinutes)
                    dataMap.putLong("timestamp", System.currentTimeMillis())
                }.asPutDataRequest().setUrgent()
                
                val dataClient = Wearable.getDataClient(this@DataLayerListenerService)
                Tasks.await(dataClient.putDataItem(putDataReq))
                Log.d(TAG, "Total sent to watch: $totalMinutes")
            } catch (e: Exception) {
                Log.e(TAG, "Send total failed: ${e.message}", e)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}
