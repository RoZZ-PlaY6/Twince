package com.twince.app

import android.content.Intent
import org.json.JSONObject

data class AlarmData(
    val taskId: String,
    val title: String,
    val description: String,
    val triggerAtMillis: Long,
    val soundType: String,
    val soundId: String,
    val soundUri: String?,
) {
    fun putInto(intent: Intent): Intent = intent
        .putExtra(EXTRA_TASK_ID, taskId)
        .putExtra(EXTRA_TITLE, title)
        .putExtra(EXTRA_DESCRIPTION, description)
        .putExtra(EXTRA_TRIGGER_AT, triggerAtMillis)
        .putExtra(EXTRA_SOUND_TYPE, soundType)
        .putExtra(EXTRA_SOUND_ID, soundId)
        .putExtra(EXTRA_SOUND_URI, soundUri)

    fun toJson(): String = JSONObject()
        .put(EXTRA_TASK_ID, taskId)
        .put(EXTRA_TITLE, title)
        .put(EXTRA_DESCRIPTION, description)
        .put(EXTRA_TRIGGER_AT, triggerAtMillis)
        .put(EXTRA_SOUND_TYPE, soundType)
        .put(EXTRA_SOUND_ID, soundId)
        .put(EXTRA_SOUND_URI, soundUri)
        .toString()

    companion object {
        const val EXTRA_TASK_ID = "taskId"
        const val EXTRA_TITLE = "title"
        const val EXTRA_DESCRIPTION = "description"
        const val EXTRA_TRIGGER_AT = "triggerAtMillis"
        const val EXTRA_SOUND_TYPE = "soundType"
        const val EXTRA_SOUND_ID = "soundId"
        const val EXTRA_SOUND_URI = "soundUri"

        fun fromMap(arguments: Map<*, *>): AlarmData? {
            val taskId = arguments[EXTRA_TASK_ID] as? String ?: return null
            val trigger = (arguments[EXTRA_TRIGGER_AT] as? Number)?.toLong()
                ?: return null
            return AlarmData(
                taskId,
                arguments[EXTRA_TITLE] as? String ?: "Task alarm",
                arguments[EXTRA_DESCRIPTION] as? String ?: "",
                trigger,
                arguments[EXTRA_SOUND_TYPE] as? String ?: "system",
                arguments[EXTRA_SOUND_ID] as? String ?: "cyber_pulse",
                arguments[EXTRA_SOUND_URI] as? String,
            )
        }

        fun fromIntent(intent: Intent): AlarmData? {
            val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return null
            return AlarmData(
                taskId,
                intent.getStringExtra(EXTRA_TITLE) ?: "Task alarm",
                intent.getStringExtra(EXTRA_DESCRIPTION) ?: "",
                intent.getLongExtra(EXTRA_TRIGGER_AT, 0L),
                intent.getStringExtra(EXTRA_SOUND_TYPE) ?: "system",
                intent.getStringExtra(EXTRA_SOUND_ID) ?: "cyber_pulse",
                intent.getStringExtra(EXTRA_SOUND_URI),
            )
        }

        fun fromJson(value: String): AlarmData? = try {
            val json = JSONObject(value)
            AlarmData(
                json.getString(EXTRA_TASK_ID),
                json.optString(EXTRA_TITLE, "Task alarm"),
                json.optString(EXTRA_DESCRIPTION, ""),
                json.getLong(EXTRA_TRIGGER_AT),
                json.optString(EXTRA_SOUND_TYPE, "system"),
                json.optString(EXTRA_SOUND_ID, "cyber_pulse"),
                json.optString(EXTRA_SOUND_URI).takeIf { it.isNotEmpty() && it != "null" },
            )
        } catch (_: Exception) {
            null
        }
    }
}
