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
    val category: String = "etc",
    val startAtMillis: Long = 0,
    val endAtMillis: Long = 0,
    val reminderIntervalMinutes: Int = 60,
    val isTimeBound: Boolean = true,
    val notificationSoundId: String = "cyber_pulse",
    val customNotificationMessage: String? = null,
    val customSystemSoundUri: String? = null,
    val notificationTimers: String = "",
) {
    fun putInto(intent: Intent): Intent = intent
        .putExtra(EXTRA_TASK_ID, taskId)
        .putExtra(EXTRA_TITLE, title)
        .putExtra(EXTRA_DESCRIPTION, description)
        .putExtra(EXTRA_TRIGGER_AT, triggerAtMillis)
        .putExtra(EXTRA_SOUND_TYPE, soundType)
        .putExtra(EXTRA_SOUND_ID, soundId)
        .putExtra(EXTRA_SOUND_URI, soundUri)
        .putExtra(EXTRA_CATEGORY, category)
        .putExtra(EXTRA_START_AT, startAtMillis)
        .putExtra(EXTRA_END_AT, endAtMillis)
        .putExtra(EXTRA_REMINDER_MINUTES, reminderIntervalMinutes)
        .putExtra(EXTRA_TIME_BOUND, isTimeBound)
        .putExtra(EXTRA_NOTIFICATION_SOUND, notificationSoundId)
        .putExtra(EXTRA_NOTIFICATION_MESSAGE, customNotificationMessage)
        .putExtra(EXTRA_NOTIFICATION_URI, customSystemSoundUri)
        .putExtra(EXTRA_NOTIFICATION_TIMERS, notificationTimers)

    fun toJson(): String = JSONObject()
        .put(EXTRA_TASK_ID, taskId)
        .put(EXTRA_TITLE, title)
        .put(EXTRA_DESCRIPTION, description)
        .put(EXTRA_TRIGGER_AT, triggerAtMillis)
        .put(EXTRA_SOUND_TYPE, soundType)
        .put(EXTRA_SOUND_ID, soundId)
        .put(EXTRA_SOUND_URI, soundUri)
        .put(EXTRA_CATEGORY, category)
        .put(EXTRA_START_AT, startAtMillis)
        .put(EXTRA_END_AT, endAtMillis)
        .put(EXTRA_REMINDER_MINUTES, reminderIntervalMinutes)
        .put(EXTRA_TIME_BOUND, isTimeBound)
        .put(EXTRA_NOTIFICATION_SOUND, notificationSoundId)
        .put(EXTRA_NOTIFICATION_MESSAGE, customNotificationMessage)
        .put(EXTRA_NOTIFICATION_URI, customSystemSoundUri)
        .put(EXTRA_NOTIFICATION_TIMERS, notificationTimers)
        .toString()

    fun toMap(): Map<String, Any?> = mapOf(
        EXTRA_TASK_ID to taskId,
        EXTRA_TITLE to title,
        EXTRA_DESCRIPTION to description,
        EXTRA_TRIGGER_AT to triggerAtMillis,
        EXTRA_SOUND_TYPE to soundType,
        EXTRA_SOUND_ID to soundId,
        EXTRA_SOUND_URI to soundUri,
        EXTRA_CATEGORY to category,
        EXTRA_START_AT to startAtMillis,
        EXTRA_END_AT to endAtMillis,
        EXTRA_REMINDER_MINUTES to reminderIntervalMinutes,
        EXTRA_TIME_BOUND to isTimeBound,
        EXTRA_NOTIFICATION_SOUND to notificationSoundId,
        EXTRA_NOTIFICATION_MESSAGE to customNotificationMessage,
        EXTRA_NOTIFICATION_URI to customSystemSoundUri,
        EXTRA_NOTIFICATION_TIMERS to notificationTimers,
    )

    companion object {
        const val EXTRA_TASK_ID = "taskId"
        const val EXTRA_TITLE = "title"
        const val EXTRA_DESCRIPTION = "description"
        const val EXTRA_TRIGGER_AT = "triggerAtMillis"
        const val EXTRA_SOUND_TYPE = "soundType"
        const val EXTRA_SOUND_ID = "soundId"
        const val EXTRA_SOUND_URI = "soundUri"
        const val EXTRA_CATEGORY = "category"
        const val EXTRA_START_AT = "startAtMillis"
        const val EXTRA_END_AT = "endAtMillis"
        const val EXTRA_REMINDER_MINUTES = "reminderIntervalMinutes"
        const val EXTRA_TIME_BOUND = "isTimeBound"
        const val EXTRA_NOTIFICATION_SOUND = "notificationSoundId"
        const val EXTRA_NOTIFICATION_MESSAGE = "customNotificationMessage"
        const val EXTRA_NOTIFICATION_URI = "customSystemSoundUri"
        const val EXTRA_NOTIFICATION_TIMERS = "notificationTimers"
        const val EXTRA_SNOOZE_MINUTES = "snoozeMinutes"

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
                arguments[EXTRA_CATEGORY] as? String ?: "etc",
                (arguments[EXTRA_START_AT] as? Number)?.toLong() ?: 0L,
                (arguments[EXTRA_END_AT] as? Number)?.toLong() ?: 0L,
                (arguments[EXTRA_REMINDER_MINUTES] as? Number)?.toInt() ?: 60,
                arguments[EXTRA_TIME_BOUND] as? Boolean ?: true,
                arguments[EXTRA_NOTIFICATION_SOUND] as? String ?: "cyber_pulse",
                arguments[EXTRA_NOTIFICATION_MESSAGE] as? String,
                arguments[EXTRA_NOTIFICATION_URI] as? String,
                arguments[EXTRA_NOTIFICATION_TIMERS] as? String ?: "",
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
                intent.getStringExtra(EXTRA_CATEGORY) ?: "etc",
                intent.getLongExtra(EXTRA_START_AT, 0L),
                intent.getLongExtra(EXTRA_END_AT, 0L),
                intent.getIntExtra(EXTRA_REMINDER_MINUTES, 60),
                intent.getBooleanExtra(EXTRA_TIME_BOUND, true),
                intent.getStringExtra(EXTRA_NOTIFICATION_SOUND) ?: "cyber_pulse",
                intent.getStringExtra(EXTRA_NOTIFICATION_MESSAGE),
                intent.getStringExtra(EXTRA_NOTIFICATION_URI),
                intent.getStringExtra(EXTRA_NOTIFICATION_TIMERS) ?: "",
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
                json.optString(EXTRA_CATEGORY, "etc"),
                json.optLong(EXTRA_START_AT, 0L),
                json.optLong(EXTRA_END_AT, 0L),
                json.optInt(EXTRA_REMINDER_MINUTES, 60),
                json.optBoolean(EXTRA_TIME_BOUND, true),
                json.optString(EXTRA_NOTIFICATION_SOUND, "cyber_pulse"),
                json.optString(EXTRA_NOTIFICATION_MESSAGE).takeIf { it.isNotEmpty() && it != "null" },
                json.optString(EXTRA_NOTIFICATION_URI).takeIf { it.isNotEmpty() && it != "null" },
                json.optString(EXTRA_NOTIFICATION_TIMERS, ""),
            )
        } catch (_: Exception) {
            null
        }
    }
}
