package com.twince.app

import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import androidx.core.app.NotificationCompat

class AlarmRingingService : Service() {
    private val queue = LinkedHashMap<String, AlarmData>()
    private var audibleId: String? = null
    private var foregroundStarted = false
    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var vibrator: Vibrator? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            val requested = intent.getStringExtra(AlarmData.EXTRA_TASK_ID) ?: audibleId
            if (requested != null) stopAlarm(requested)
            return START_NOT_STICKY
        }
        val data = intent?.let(AlarmData::fromIntent) ?: return START_NOT_STICKY
        queue[data.taskId] = data
        audibleId = data.taskId
        createChannel()
        acquireWakeLock()
        publishNotifications(offerFullScreen = true)
        startSound(data)
        startVibration()
        if (AlarmActivity.isVisible) {
            startActivity(activityIntent(data))
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releasePlayer()
        stopVibration()
        abandonAudioFocus()
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    private fun stopAlarm(taskId: String) {
        val removed = queue.remove(taskId)
        getSystemService(NotificationManager::class.java).cancel(notificationId(taskId))
        val wasAudible = audibleId == taskId
        if (wasAudible) {
            releasePlayer()
            stopVibration()
            audibleId = queue.keys.lastOrNull()
            audibleId?.let { nextId ->
                startSound(queue.getValue(nextId))
                startVibration()
            }
        }
        if (queue.isEmpty()) {
            audibleId = null
            wakeLock?.let { if (it.isHeld) it.release() }
            wakeLock = null
            if (foregroundStarted) {
                stopForeground(STOP_FOREGROUND_REMOVE)
                foregroundStarted = false
            }
            stopSelf()
        } else {
            publishNotifications(offerFullScreen = false)
        }
        if (removed != null) announce(taskId, if (wasAudible) queue[audibleId] else null)
    }

    private fun announce(stoppedTaskId: String, next: AlarmData?) {
        val intent = Intent(AlarmActionReceiver.ACTION_QUEUE_CHANGED)
            .setPackage(packageName)
            .putExtra(AlarmData.EXTRA_TASK_ID, stoppedTaskId)
        if (next != null) intent.putExtra(EXTRA_NEXT_ALARM, next.toJson())
        sendBroadcast(intent)
    }

    private fun publishNotifications(offerFullScreen: Boolean) {
        val audible = audibleId?.let(queue::get) ?: return
        val notification = buildNotification(
            audible,
            fullScreen = offerFullScreen && shouldOpenFullScreen(),
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                FOREGROUND_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(FOREGROUND_ID, notification)
        }
        foregroundStarted = true
        val manager = getSystemService(NotificationManager::class.java)
        for ((id, alarm) in queue) {
            if (id == audibleId) {
                manager.cancel(notificationId(id))
            } else {
                manager.notify(notificationId(id), buildNotification(alarm, fullScreen = false))
            }
        }
    }

    private fun shouldOpenFullScreen(): Boolean {
        val power = getSystemService(PowerManager::class.java)
        val keyguard = getSystemService(KeyguardManager::class.java)
        if (power.isInteractive && !keyguard.isKeyguardLocked) return false
        if (Build.VERSION.SDK_INT >= 34) {
            val manager = getSystemService(NotificationManager::class.java)
            if (!manager.canUseFullScreenIntent()) return false
        }
        return true
    }

    private fun buildNotification(
        data: AlarmData,
        fullScreen: Boolean,
    ): android.app.Notification {
        val open = activityPending(data)
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_icon)
            .setContentTitle(data.title)
            .setContentText("Time to start your task")
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(open)
            .addAction(0, "Dismiss", actionIntent(data, AlarmActionReceiver.ACTION_DISMISS, 1))
            .addAction(0, "Restart", actionIntent(data, AlarmActionReceiver.ACTION_RESTART, 2))
            .addAction(0, "Snooze 5min", snoozeIntent(data, 5, 3))
            .addAction(0, "Snooze 10min", snoozeIntent(data, 10, 4))
        if (fullScreen) builder.setFullScreenIntent(open, true)
        return builder.build()
    }

    private fun activityIntent(data: AlarmData): Intent =
        data.putInto(Intent(this, AlarmActivity::class.java))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

    private fun activityPending(data: AlarmData): PendingIntent =
        PendingIntent.getActivity(
            this,
            notificationId(data.taskId),
            activityIntent(data),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun snoozeIntent(data: AlarmData, minutes: Int, suffix: Int): PendingIntent {
        val intent = data.putInto(
            Intent(this, AlarmActionReceiver::class.java)
                .setAction(AlarmActionReceiver.ACTION_SNOOZE),
        ).putExtra(AlarmData.EXTRA_SNOOZE_MINUTES, minutes)
        return PendingIntent.getBroadcast(
            this,
            (data.taskId.hashCode() * 10 + suffix) and Int.MAX_VALUE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
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
            enableVibration(false)
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

    private fun startVibration() {
        stopVibration()
        val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = longArrayOf(0, 800, 400, 800, 1200)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vib.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vib.vibrate(pattern, 0)
        }
        vibrator = vib
    }

    private fun stopVibration() {
        vibrator?.cancel()
        vibrator = null
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Twince:AlarmRinging")
            .apply { acquire(15 * 60 * 1000L) }
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
        const val EXTRA_NEXT_ALARM = "nextAlarm"
        private const val CHANNEL_ID = "twince_ringing_alarms_v2"
        private const val FOREGROUND_ID = 0x41A2C

        fun notificationId(taskId: String): Int =
            (taskId.hashCode() xor 0x41A2C) and Int.MAX_VALUE
    }
}
