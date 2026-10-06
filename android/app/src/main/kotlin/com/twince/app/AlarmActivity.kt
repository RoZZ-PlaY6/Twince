package com.twince.app

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class AlarmActivity : Activity() {
    private var data: AlarmData? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
        )
        data = AlarmData.fromIntent(intent)
        if (data == null) {
            finish()
            return
        }
        setContentView(buildContent(data!!))
    }

    private fun buildContent(alarm: AlarmData): LinearLayout {
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(28), dp(48), dp(28), dp(48))
            setBackgroundColor(Color.rgb(10, 12, 20))
            addView(TextView(this@AlarmActivity).apply {
                text = "TWINCE ALARM"
                textSize = 18f
                setTextColor(Color.rgb(0, 229, 255))
                gravity = Gravity.CENTER
                letterSpacing = .12f
            })
            addView(TextView(this@AlarmActivity).apply {
                text = alarm.title
                textSize = 34f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                setPadding(0, dp(30), 0, dp(12))
            })
            if (alarm.description.isNotBlank()) {
                addView(TextView(this@AlarmActivity).apply {
                    text = alarm.description
                    textSize = 17f
                    setTextColor(Color.LTGRAY)
                    gravity = Gravity.CENTER
                    setPadding(0, 0, 0, dp(36))
                })
            }
            addView(Button(this@AlarmActivity).apply {
                text = "Snooze 10 minutes"
                setOnClickListener { act(AlarmActionReceiver.ACTION_SNOOZE) }
            }, ViewGroup.LayoutParams.MATCH_PARENT, dp(56))
            addView(Button(this@AlarmActivity).apply {
                text = "Dismiss"
                setOnClickListener { act(AlarmActionReceiver.ACTION_DISMISS) }
            }, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(56),
            ).apply { topMargin = dp(12) })
        }
    }

    private fun act(action: String) {
        data?.putInto(Intent(this, AlarmActionReceiver::class.java).setAction(action))
            ?.let(::sendBroadcast)
        finishAndRemoveTask()
    }
}
