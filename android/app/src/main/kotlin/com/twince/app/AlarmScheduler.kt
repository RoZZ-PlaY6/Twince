package com.twince.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object AlarmScheduler {
    private const val PREFS = "twince_exact_alarms"
    private const val PREFIX = "alarm:"

    fun canSchedule(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return context.getSystemService(AlarmManager::class.java)
            .canScheduleExactAlarms()
    }

    fun schedule(context: Context, data: AlarmData): Boolean {
        if (!canSchedule(context) || data.triggerAtMillis <= System.currentTimeMillis()) {
            return false
        }
        val manager = context.getSystemService(AlarmManager::class.java)
        manager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            data.triggerAtMillis,
            pendingIntent(context, data),
        )
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(PREFIX + data.taskId, data.toJson())
            .apply()
        return true
    }

    fun cancel(context: Context, taskId: String) {
        val placeholder = AlarmData(taskId, "", "", 0, "system", "", null)
        context.getSystemService(AlarmManager::class.java)
            .cancel(pendingIntent(context, placeholder))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(PREFIX + taskId)
            .apply()
        context.startService(
            Intent(context, AlarmRingingService::class.java)
                .setAction(AlarmRingingService.ACTION_STOP)
                .putExtra(AlarmData.EXTRA_TASK_ID, taskId),
        )
    }

    fun markFired(context: Context, taskId: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .remove(PREFIX + taskId)
            .apply()
    }

    fun restore(context: Context) {
        if (!canSchedule(context)) return
        val values = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).all
        for ((key, value) in values) {
            if (!key.startsWith(PREFIX) || value !is String) continue
            val data = AlarmData.fromJson(value) ?: continue
            if (data.triggerAtMillis > System.currentTimeMillis()) {
                schedule(context, data)
            } else {
                markFired(context, data.taskId)
            }
        }
    }

    private fun pendingIntent(context: Context, data: AlarmData): PendingIntent {
        val intent = data.putInto(Intent(context, AlarmReceiver::class.java))
        return PendingIntent.getBroadcast(
            context,
            data.taskId.hashCode() and Int.MAX_VALUE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
