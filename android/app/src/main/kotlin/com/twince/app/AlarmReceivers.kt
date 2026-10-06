package com.twince.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val data = AlarmData.fromIntent(intent) ?: return
        AlarmScheduler.markFired(context, data.taskId)
        ContextCompat.startForegroundService(
            context,
            data.putInto(Intent(context, AlarmRingingService::class.java)),
        )
    }
}

class AlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val data = AlarmData.fromIntent(intent) ?: return
        context.startService(
            Intent(context, AlarmRingingService::class.java)
                .setAction(AlarmRingingService.ACTION_STOP)
                .putExtra(AlarmData.EXTRA_TASK_ID, data.taskId),
        )
        if (intent.action == ACTION_SNOOZE) {
            AlarmScheduler.schedule(
                context,
                data.copy(triggerAtMillis = System.currentTimeMillis() + SNOOZE_MILLIS),
            )
        }
    }

    companion object {
        const val ACTION_DISMISS = "com.twince.app.DISMISS_ALARM"
        const val ACTION_SNOOZE = "com.twince.app.SNOOZE_ALARM"
        private const val SNOOZE_MILLIS = 10 * 60 * 1000L
    }
}

class AlarmBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (
            intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            AlarmScheduler.restore(context)
        }
    }
}
