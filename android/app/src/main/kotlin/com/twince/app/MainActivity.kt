package com.twince.app

import android.app.Activity
import android.app.AlarmManager
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var importResult: MethodChannel.Result? = null
    private var alarmPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "twince/export")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val fileName = call.argument<String>("fileName") ?: "twince_backup.json"
                val mimeType = call.argument<String>("mimeType") ?: "application/json"
                if (path == null) {
                    result.error("INVALID_PATH", "Backup file path is missing", null)
                    return@setMethodCallHandler
                }
                try {
                    val file = File(path)
                    val authority = "${applicationContext.packageName}.fileprovider"
                    val uri = FileProvider.getUriForFile(
                        this,
                        authority,
                        file,
                    )
                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                        type = mimeType
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_TITLE, fileName)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(shareIntent, "Share Twince backup"))
                    result.success(true)
                } catch (error: Exception) {
                    result.error("SHARE_FAILED", error.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "twince/import")
            .setMethodCallHandler { call, result ->
                if (call.method != "pickAndReadFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                importResult = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    type = "application/json"
                    addCategory(Intent.CATEGORY_OPENABLE)
                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json"))
                }
                startActivityForResult(intent, 42)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "twince/alarms")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canScheduleExactAlarms" -> result.success(AlarmScheduler.canSchedule(this))
                    "requestExactAlarmAccess" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                            !getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
                        ) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    }
                    "schedule" -> {
                        val data = AlarmData.fromMap(call.arguments as? Map<*, *> ?: emptyMap<Any, Any>())
                        if (data == null) {
                            result.error("INVALID_ALARM", "Alarm data is incomplete", null)
                        } else {
                            result.success(AlarmScheduler.schedule(this, data))
                        }
                    }
                    "cancel" -> {
                        val taskId = call.argument<String>("taskId")
                        if (taskId == null) {
                            result.error("INVALID_TASK", "Task id is missing", null)
                        } else {
                            AlarmScheduler.cancel(this, taskId)
                            result.success(true)
                        }
                    }
                    "pickSystemSound" -> {
                        alarmPickerResult = result
                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(
                                RingtoneManager.EXTRA_RINGTONE_TYPE,
                                RingtoneManager.TYPE_ALARM or RingtoneManager.TYPE_RINGTONE,
                            )
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                        }
                        startActivityForResult(intent, REQUEST_SYSTEM_SOUND)
                    }
                    "pickCustomAudio" -> {
                        alarmPickerResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            type = "audio/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                            addFlags(
                                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                            )
                        }
                        startActivityForResult(intent, REQUEST_CUSTOM_AUDIO)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_SYSTEM_SOUND || requestCode == REQUEST_CUSTOM_AUDIO) {
            val result = alarmPickerResult
            alarmPickerResult = null
            if (result == null) return
            if (resultCode != Activity.RESULT_OK || data == null) {
                result.success(null)
                return
            }
            val uri = if (requestCode == REQUEST_SYSTEM_SOUND) {
                @Suppress("DEPRECATION")
                data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI) as? Uri
            } else {
                data.data
            }
            if (uri == null) {
                result.success(null)
                return
            }
            if (requestCode == REQUEST_CUSTOM_AUDIO) {
                runCatching {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION,
                    )
                }
            }
            val label = if (requestCode == REQUEST_SYSTEM_SOUND) {
                RingtoneManager.getRingtone(this, uri)?.getTitle(this) ?: "System alarm"
            } else {
                displayName(uri) ?: "Custom audio"
            }
            result.success(mapOf("uri" to uri.toString(), "label" to label))
            return
        }
        if (requestCode == 42) {
            val result = importResult
            importResult = null
            if (result == null) return
            if (resultCode == Activity.RESULT_OK && data != null) {
                data.data?.let { uri ->
                    contentResolver.openInputStream(uri)?.use { inputStream ->
                        val content = inputStream.readBytes().decodeToString()
                        result.success(content)
                    } ?: result.error("READ_FAILED", "Failed to read file", null)
                } ?: result.error("NO_URI", "No file selected", null)
            } else {
                result.error("CANCELLED", "File picker cancelled", null)
            }
        }
    }

    private fun displayName(uri: Uri): String? {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) return cursor.getString(0)
            }
        return null
    }

    companion object {
        private const val REQUEST_SYSTEM_SOUND = 43
        private const val REQUEST_CUSTOM_AUDIO = 44
    }
}
