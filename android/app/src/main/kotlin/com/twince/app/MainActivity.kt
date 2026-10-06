package com.twince.app

import android.app.Activity
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var importResult: MethodChannel.Result? = null

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
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
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
}
