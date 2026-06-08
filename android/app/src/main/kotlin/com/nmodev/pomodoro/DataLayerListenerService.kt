package com.nmodev.pomodoro

import android.content.Intent
import android.util.Log
import com.google.android.gms.wearable.*
import com.google.android.gms.tasks.Tasks
import kotlinx.coroutines.*

class DataLayerListenerService : WearableListenerService() {
    private val scope = CoroutineScope(Dispatchers.Main + Job())
    private val TAG = "DataLayerListener"

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        try {
            for (i in 0 until dataEvents.count) {
                val event = dataEvents.get(i)
                if (event.type == DataEvent.TYPE_CHANGED) {
                    val item = event.dataItem
                    when (item.uri.path) {
                        "/pomodoro_session" -> handlePomodoroSession(item)
                    }
                }
            }
        } finally {
            dataEvents.release()
        }
    }

    private fun handlePomodoroSession(item: DataItem) {
        val dataMap = DataMapItem.fromDataItem(item).dataMap
        val minutes = dataMap.getInt("minutes", 0)

        Log.d(TAG, "Received session: $minutes minutes")

        scope.launch {
            val newTotal = withContext(Dispatchers.IO) {
                val total = PhoneWearSync.addWorkMinutes(this@DataLayerListenerService, minutes)
                PhoneWearSync.pushTotalStatsToWatch(this@DataLayerListenerService, total)
                total
            }
            broadcastWatchSessionToFlutter(minutes, newTotal)
        }
    }

    private fun broadcastWatchSessionToFlutter(sessionMinutes: Int, totalWorkMinutes: Int) {
        val intent = Intent("com.nmodev.pomodoro.SESSION_UPDATE").apply {
            setPackage(packageName)
            putExtra("totalWorkMinutes", totalWorkMinutes)
            putExtra("sessionMinutes", sessionMinutes)
            putExtra("source", "watch")
            putExtra("isCompleted", true)
            putExtra("isReset", false)
            putExtra("timestamp", System.currentTimeMillis())
        }
        sendBroadcast(intent)
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        when (messageEvent.path) {
            "/request_total" -> {
                scope.launch {
                    val total = withContext(Dispatchers.IO) {
                        PhoneWearSync.getTotalWorkMinutes(this@DataLayerListenerService)
                    }
                    withContext(Dispatchers.IO) {
                        PhoneWearSync.pushTotalStatsToWatch(this@DataLayerListenerService, total)
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}
