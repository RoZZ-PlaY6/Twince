package com.twince.app

import android.content.Context

/// Holds Restart requests until Flutter can create the new task.
/// The original task id is not reused and its Hive record is not edited here.
object AlarmRestartQueue {
    private const val PREFS = "twince_alarm_restarts"
    var onPending: (() -> Unit)? = null

    fun enqueue(context: Context, data: AlarmData) {
        val duration = (data.endAtMillis - data.startAtMillis).takeIf { it > 0 }
            ?: 60 * 60 * 1000L
        val start = System.currentTimeMillis()
        val window = data.copy(
            startAtMillis = start,
            endAtMillis = start + duration,
            triggerAtMillis = start + duration,
        )
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString("${data.taskId}:$start", window.toJson())
            .apply()
        onPending?.invoke()
    }

    fun consume(context: Context): List<Map<String, Any?>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val maps = prefs.all.mapNotNull { (_, value) ->
            if (value !is String) return@mapNotNull null
            AlarmData.fromJson(value)?.toMap()
        }
        prefs.edit().clear().apply()
        return maps
    }
}
