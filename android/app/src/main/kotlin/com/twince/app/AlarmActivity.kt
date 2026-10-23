package com.twince.app

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AlarmActivity : Activity() {
    private var data: AlarmData? = null
    private var root: FrameLayout? = null

    private val queueReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val stopped = intent.getStringExtra(AlarmData.EXTRA_TASK_ID) ?: return
            if (stopped != data?.taskId) return
            val next = intent.getStringExtra(AlarmRingingService.EXTRA_NEXT_ALARM)
                ?.let(AlarmData::fromJson)
            if (next == null) {
                finish()
            } else {
                data = next
                render()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        data = AlarmData.fromIntent(intent)
        if (data == null) {
            finish()
            return
        }
        val filter = IntentFilter(AlarmActionReceiver.ACTION_QUEUE_CHANGED)
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(queueReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(queueReceiver, filter)
        }
        root = FrameLayout(this)
        setContentView(root)
        render()
    }

    override fun onStart() {
        super.onStart()
        isVisible = true
    }

    override fun onStop() {
        isVisible = false
        super.onStop()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val incoming = AlarmData.fromIntent(intent) ?: return
        if (incoming.taskId == data?.taskId) return
        data = incoming
        render()
    }

    override fun onDestroy() {
        runCatching { unregisterReceiver(queueReceiver) }
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        super.onDestroy()
    }

    @Deprecated("Back only closes this screen. It does not complete the task.")
    override fun onBackPressed() {
        finish()
    }

    private fun render() {
        val alarm = data ?: return
        val host = root ?: return
        host.removeAllViews()
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()
        val width = resources.displayMetrics.widthPixels
        val circle = ((width - dp(72)) / 2).coerceIn(dp(108), dp(148))

        host.background = GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(Color.parseColor("#07102F"), Color.parseColor("#1A0A3C")),
        )
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            val scroll = ScrollView(this@AlarmActivity).apply {
                isFillViewport = true
                addView(this@apply, FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                ))
            }
            host.addView(scroll, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ))
        }
        ViewCompat.setOnApplyWindowInsetsListener(content) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(
                bars.left + dp(22),
                bars.top + dp(28),
                bars.right + dp(22),
                bars.bottom + dp(22),
            )
            insets
        }
        ViewCompat.requestApplyInsets(content)

        content.addView(label("TWINCE", 13f, Color.parseColor("#9AADD6"), 0.28f))
        content.addView(label(clock(alarm), 58f, Color.WHITE, -0.03f).apply {
            setPadding(0, dp(28), 0, 0)
            setTypeface(typeface, Typeface.NORMAL)
        })
        content.addView(label("Alarm", 22f, Color.WHITE, 0f).apply {
            setPadding(0, dp(6), 0, dp(18))
        })
        content.addView(ImageView(this).apply {
            setImageResource(R.drawable.ic_alarm_bell)
            layoutParams = LinearLayout.LayoutParams(dp(86), dp(86))
        })
        content.addView(label(alarm.title.ifBlank { "Task alarm" }, 28f, Color.WHITE, 0f).apply {
            setTypeface(typeface, Typeface.BOLD)
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            setPadding(0, dp(22), 0, dp(6))
        })
        content.addView(label("Time to start your task", 16f, Color.parseColor("#C4B5FD"), 0f).apply {
            setTypeface(typeface, Typeface.ITALIC)
            setPadding(0, 0, 0, dp(28))
        })

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        actions.addView(circleButton(
            "Dismiss",
            R.drawable.ic_alarm_dismiss,
            Color.parseColor("#38BDF8"),
            Color.parseColor("#102044"),
            circle,
        ) { act(AlarmActionReceiver.ACTION_DISMISS) })
        actions.addView(circleButton(
            "Restart",
            R.drawable.ic_alarm_restart,
            Color.parseColor("#C4B5FD"),
            Color.parseColor("#1B1248"),
            circle,
        ) { act(AlarmActionReceiver.ACTION_RESTART) }, LinearLayout.LayoutParams(circle, circle).apply {
            marginStart = dp(18)
        })
        content.addView(actions)

        val snoozes = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dp(22), 0, 0)
        }
        snoozes.addView(pill("Snooze 5min", Color.parseColor("#38BDF8")) {
            act(AlarmActionReceiver.ACTION_SNOOZE, 5)
        }, LinearLayout.LayoutParams(0, dp(52), 1f))
        snoozes.addView(pill("Snooze 10min", Color.parseColor("#A78BFA")) {
            act(AlarmActionReceiver.ACTION_SNOOZE, 10)
        }, LinearLayout.LayoutParams(0, dp(52), 1f).apply { marginStart = dp(12) })
        content.addView(snoozes)
    }

    private fun label(text: String, size: Float, color: Int, spacing: Float) =
        TextView(this).apply {
            this.text = text
            textSize = size
            setTextColor(color)
            gravity = Gravity.CENTER
            textAlignment = View.TEXT_ALIGNMENT_CENTER
            letterSpacing = spacing
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }

    private fun circleButton(
        caption: String,
        icon: Int,
        glow: Int,
        fill: Int,
        size: Int,
        onClick: () -> Unit,
    ): LinearLayout {
        val density = resources.displayMetrics.density
        val circle = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(fill)
            setStroke((2.2f * density).toInt(), glow)
        }
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = circle
            elevation = 18f * density
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                outlineAmbientShadowColor = glow
                outlineSpotShadowColor = glow
            }
            layoutParams = LinearLayout.LayoutParams(size, size)
            setOnClickListener { onClick() }
            addView(ImageView(this@AlarmActivity).apply {
                setImageResource(icon)
                layoutParams = LinearLayout.LayoutParams((28 * density).toInt(), (28 * density).toInt())
            })
            addView(TextView(this@AlarmActivity).apply {
                text = caption
                textSize = 15f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                setPadding(0, (8 * density).toInt(), 0, 0)
            })
        }
    }

    private fun pill(caption: String, stroke: Int, onClick: () -> Unit) =
        TextView(this).apply {
            text = caption
            textSize = 15f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                cornerRadius = 999f
                setColor(Color.parseColor("#102044"))
                setStroke((1.6f * resources.displayMetrics.density).toInt(), stroke)
            }
            setOnClickListener { onClick() }
        }

    private fun clock(alarm: AlarmData): String {
        val millis = if (alarm.triggerAtMillis > 0) alarm.triggerAtMillis else System.currentTimeMillis()
        return SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(millis))
    }

    private fun act(action: String, minutes: Int = 0) {
        val intent = Intent(this, AlarmActionReceiver::class.java).setAction(action)
        if (minutes > 0) intent.putExtra(AlarmData.EXTRA_SNOOZE_MINUTES, minutes)
        data?.putInto(intent)?.let(::sendBroadcast)
    }

    companion object {
        @Volatile
        var isVisible: Boolean = false
    }
}
