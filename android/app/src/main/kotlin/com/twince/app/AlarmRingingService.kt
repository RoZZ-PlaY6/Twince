package com.twince.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.IBinder
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat

class AlarmRingingService : Service() {
    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var activeTaskId: String? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            val requestedTask = intent.getStringExtra(AlarmData.EXTRA_TASK_ID)
            if (requestedTask == null || requestedTask == activeTaskId) stopRinging()
            return START_NOT_STICKY
        }
        val data = intent?.let(AlarmData::fromIntent) ?: return START_NOT_STICKY
        activeTaskId = data.taskId
        createChannel()
        startForeground(notificationId(data.taskId), buildNotification(data))
        acquireWakeLock()
        startSound(data)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseResources()
        super.onDestroy()
    }

    private fun buildNotification(data: AlarmData): android.app.Notification {
        val fullScreen = PendingIntent.getActivity(
            this,
            notificationId(data.taskId),
            data.putInto(Intent(this, AlarmActivity::class.java)),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val dismiss = actionIntent(data, AlarmActionReceiver.ACTION_DISMISS, 1)
        val snooze = actionIntent(data, AlarmActionReceiver.ACTION_SNOOZE, 2)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_icon)
            .setContentTitle(data.title)
            .setContentText(data.description.ifBlank { "Task alarm is ringing" })
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fullScreen, true)
            .setContentIntent(fullScreen)
            .addAction(0, "Snooze 10 min", snooze)
            .addAction(0, "Dismiss", dismiss)
            .build()
    }

    private fun actionIntent(data: AlarmData, action: String, suffix: Int): PendingIntent {
        val intent = data.putInto(Intent(this, AlarmActionReceiver::class.java).setAction(action))
        return PendingIntent.getBroadcast(
            this,
            (data.taskId.hashCode() * 10 + suffix) and Int.MAX_VALUE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Ringing task alarms",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Full-screen alarms for alarmed tasks"
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            setSound(null, null)
            enableVibration(true)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun startSound(data: AlarmData) {
        releasePlayer()
        requestAudioFocus()
        val uri = when (data.soundType) {
            "builtIn" -> {
                val resource = resources.getIdentifier(data.soundId, "raw", packageName)
                if (resource != 0) Uri.parse("android.resource://$packageName/$resource")
                else Settings.System.DEFAULT_ALARM_ALERT_URI
            }
            "customFile" -> data.soundUri?.let(Uri::parse)
            "system" -> data.soundUri?.let(Uri::parse)
            else -> null
        } ?: Settings.System.DEFAULT_ALARM_ALERT_URI

        player = runCatching { createPlayer(uri) }
            .getOrElse { createPlayer(Settings.System.DEFAULT_ALARM_ALERT_URI) }
    }

    private fun createPlayer(uri: Uri): MediaPlayer =
        MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            setDataSource(this@AlarmRingingService, uri)
            isLooping = true
            prepare()
            start()
        }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Twince:AlarmRinging")
            .apply { acquire(15 * 60 * 1000L) }
    }

    private fun stopRinging() {
        releaseResources()
        activeTaskId?.let {
            getSystemService(NotificationManager::class.java).cancel(notificationId(it))
        }
        activeTaskId = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun releaseResources() {
        releasePlayer()
        abandonAudioFocus()
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    private fun releasePlayer() {
        player?.runCatching {
            stop()
            release()
        }
        player = null
    }

    private fun requestAudioFocus() {
        val manager = getSystemService(AudioManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                .build()
                .also { manager.requestAudioFocus(it) }
        } else {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(
                null,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            )
        }
    }

    private fun abandonAudioFocus() {
        val manager = getSystemService(AudioManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let(manager::abandonAudioFocusRequest)
        } else {
            @Suppress("DEPRECATION")
            manager.abandonAudioFocus(null)
        }
        audioFocusRequest = null
    }

    companion object {
        const val ACTION_STOP = "com.twince.app.STOP_RINGING"
        private const val CHANNEL_ID = "twince_ringing_alarms"

        fun notificationId(taskId: String): Int =
            (taskId.hashCode() xor 0x41A2C) and Int.MAX_VALUE
    }
}
