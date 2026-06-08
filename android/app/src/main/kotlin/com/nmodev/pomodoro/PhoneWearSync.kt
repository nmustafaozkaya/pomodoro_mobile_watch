package com.nmodev.pomodoro

import android.content.Context
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable

/**
 * Telefon tarafında Wear Data Layer ile saate giden veriler.
 * API kullanılmadan toplam çalışma ve pomodoro süresi ayarlarını senkronlar.
 */
object PhoneWearSync {
    private const val TAG = "PhoneWearSync"
    const val PREFS_WORK = "pomodoro_work_data"

    fun getTotalWorkMinutes(context: Context): Int {
        val prefs = context.getSharedPreferences(PREFS_WORK, Context.MODE_PRIVATE)
        return prefs.getInt("totalWorkMinutes", 0)
    }

    /** Saatten gelen veya telefondan eklenen dakikaları native toplama yazar. */
    fun addWorkMinutes(context: Context, minutes: Int): Int {
        if (minutes <= 0) return getTotalWorkMinutes(context)
        val prefs = context.getSharedPreferences(PREFS_WORK, Context.MODE_PRIVATE)
        val newTotal = prefs.getInt("totalWorkMinutes", 0) + minutes
        prefs.edit().putInt("totalWorkMinutes", newTotal).apply()
        return newTotal
    }

    fun pushTotalStatsToWatch(context: Context, totalMinutes: Int) {
        try {
            val req = PutDataMapRequest.create("/total_stats").apply {
                dataMap.putInt("totalMinutes", totalMinutes)
                dataMap.putLong("timestamp", System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()
            Tasks.await(Wearable.getDataClient(context).putDataItem(req))
            Log.d(TAG, "pushTotalStats: $totalMinutes")
        } catch (e: Exception) {
            Log.w(TAG, "pushTotalStats failed: ${e.message}")
        }
    }

    /** Telefonda biten pomodoro oturumunu native toplama ekler ve saate yollar. */
    fun addPhoneSessionAndSyncWatch(context: Context, minutes: Int) {
        if (minutes <= 0) return
        val total = addWorkMinutes(context, minutes)
        pushTotalStatsToWatch(context, total)
    }

    fun pushTimerSettingsToWatch(
        context: Context,
        selectedMinutes: Int,
        breakMinutes: Int,
        language: String,
    ) {
        try {
            val req = PutDataMapRequest.create("/pomodoro_settings").apply {
                dataMap.putInt("selectedMinutes", selectedMinutes)
                dataMap.putInt("breakMinutes", breakMinutes)
                dataMap.putString("language", language)
                dataMap.putLong("timestamp", System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()
            Tasks.await(Wearable.getDataClient(context).putDataItem(req))
            Log.d(TAG, "pushTimerSettings: $selectedMinutes min, break $breakMinutes")
        } catch (e: Exception) {
            Log.w(TAG, "pushTimerSettings failed: ${e.message}")
        }
    }
}
