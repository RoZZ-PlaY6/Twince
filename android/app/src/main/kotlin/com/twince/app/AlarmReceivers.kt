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
        when (intent.action) {
            ACTION_SNOOZE -> {
                val minutes = intent.getIntExtra(AlarmData.EXTRA_SNOOZE_MINUTES, 0)
                if (minutes == 5 || minutes == 10) {
                    AlarmScheduler.schedule(
                        context,
                        data.copy(
                            triggerAtMillis =
                                System.currentTimeMillis() + minutes * 60_000L,
                        ),
                    )
                }
            }
            ACTION_RESTART -> AlarmRestartQueue.enqueue(context, data)
        }
    }

    companion object {
        const val ACTION_DISMISS = "com.twince.app.DISMISS_ALARM"
        const val ACTION_SNOOZE = "com.twince.app.SNOOZE_ALARM"
        const val ACTION_RESTART = "com.twince.app.RESTART_ALARM"
        const val ACTION_QUEUE_CHANGED = "com.twince.app.ALARM_QUEUE_CHANGED"
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
