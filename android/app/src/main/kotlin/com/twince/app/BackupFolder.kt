package com.twince.app

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Public Documents/Twince access through the system document provider. */
class BackupFolder(private val activity: MainActivity) {
    private val prefs = activity.getSharedPreferences("twince_public_backups", 0)
    private var pending: MethodChannel.Result? = null
    private val resolver get() = activity.contentResolver
    private val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prepare" -> {
                try { result.success(folder() != null) }
                catch (e: Exception) { result.error("STORAGE", e.message, null) }
            }
            "authorize" -> authorize(result)
            "create" -> {
                try {
                    val parent = folder() ?: throw IllegalStateException("Select Documents to grant backup access.")
                    migrate(parent)
                    val name = call.argument<String>("name") ?: throw IllegalArgumentException("Missing backup name")
                    val contents = call.argument<String>("contents") ?: throw IllegalArgumentException("Missing backup data")
                    if (find(parent, name) != null) throw IllegalStateException("A backup with that name already exists. Choose another name.")
                    result.success(create(parent, name, contents))
                } catch (e: Exception) { result.error("STORAGE", e.message, null) }
            }
            "save" -> {
                try {
                    val parent = folder() ?: throw IllegalStateException("Select Documents to grant backup access.")
                    migrate(parent)
                    val name = call.argument<String>("name") ?: throw IllegalArgumentException("Missing backup name")
                    val contents = call.argument<String>("contents") ?: throw IllegalArgumentException("Missing backup data")
                    val oldPath = call.argument<String>("path")
                    val oldUri = call.argument<String>("uri")
                    val mapped = oldPath?.let { prefs.getString("legacy:$it", null) }
                    val target = mapped ?: oldUri?.takeIf { isInFolder(parent, it) }
                    if (target == null) {
                        // Imported files and legacy backups remain unchanged; create a distinct public copy.
                        val fresh = uniqueName(parent, name)
                        result.success(mapOf("uri" to create(parent, fresh, contents), "name" to fresh))
                    } else {
                        writeAndVerify(Uri.parse(target), contents)
                        val actualName = displayName(Uri.parse(target)) ?: name
                        result.success(mapOf("uri" to target, "name" to actualName))
                    }
                } catch (e: Exception) { result.error("STORAGE", e.message, null) }
            }
            else -> result.notImplemented()
        }
    }

    private fun authorize(result: MethodChannel.Result) {
        if (pending != null) { result.error("BUSY", "Folder selection is already open.", null); return }
        pending = result
        AlertDialog.Builder(activity)
            .setTitle("Backup folder access")
            .setMessage("Select the Documents folder and tap Allow. Twince will create and use Documents/Twince for backups.")
            .setNegativeButton("Cancel") { _, _ -> pending?.success(false); pending = null }
            .setPositiveButton("Choose Documents") { _, _ ->
                try {
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(flags or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse("content://com.android.externalstorage.documents/document/primary%3ADocuments"))
                    }
                    activity.startActivityForResult(intent, REQUEST_FOLDER)
                } catch (e: Exception) { pending?.error("STORAGE", e.message, null); pending = null }
            }.setOnCancelListener { pending?.success(false); pending = null }.show()
    }

    fun onResult(request: Int, resultCode: Int, data: Intent?): Boolean {
        if (request != REQUEST_FOLDER) return false
        val reply = pending ?: return true
        pending = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) { reply.success(false); return true }
        try {
            val tree = data.data!!
            val id = DocumentsContract.getTreeDocumentId(tree)
            if (tree.authority != "com.android.externalstorage.documents" || id != "primary:Documents") {
                throw IllegalArgumentException("Select the Documents folder in internal storage, then tap Allow.")
            }
            resolver.takePersistableUriPermission(tree, flags)
            prefs.edit().putString("tree", tree.toString()).apply()
            val parent = folder() ?: throw IllegalStateException("Could not create Documents/Twince.")
            migrate(parent)
            reply.success(true)
        } catch (e: Exception) { reply.error("STORAGE", e.message, null) }
        return true
    }

    private fun folder(): Uri? {
        val tree = prefs.getString("tree", null)?.let(Uri::parse) ?: return null
        if (resolver.persistedUriPermissions.none { it.uri == tree && it.isReadPermission && it.isWritePermission }) return null
        val root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        val existing = find(root, "Twince")
        return existing ?: DocumentsContract.createDocument(resolver, root, DocumentsContract.Document.MIME_TYPE_DIR, "Twince")
            ?: throw IllegalStateException("Could not create Documents/Twince.")
    }

    private fun find(parent: Uri, name: String): Uri? {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(parent, DocumentsContract.getDocumentId(parent))
        resolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { c ->
            while (c.moveToNext()) if (c.getString(1) == name) return DocumentsContract.buildDocumentUriUsingTree(parent, c.getString(0))
        } ?: throw IllegalStateException("Cannot read Documents/Twince. Check folder access.")
        return null
    }

    private fun displayName(uri: Uri): String? {
        resolver.query(uri, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use { c -> if (c.moveToFirst()) return c.getString(0) }
        return null
    }

    private fun isInFolder(parent: Uri, text: String): Boolean = try {
        val uri = Uri.parse(text)
        uri.authority == parent.authority && DocumentsContract.getDocumentId(uri).startsWith(DocumentsContract.getDocumentId(parent) + "/")
    } catch (_: Exception) { false }

    private fun uniqueName(parent: Uri, name: String): String {
        if (find(parent, name) == null) return name
        val base = name.removeSuffix(".json")
        var number = 1
        while (find(parent, "$base ($number).json") != null) number++
        return "$base ($number).json"
    }

    private fun create(parent: Uri, name: String, contents: String): String {
        val uri = DocumentsContract.createDocument(resolver, parent, "application/json", name)
            ?: throw IllegalStateException("Could not create the backup file.")
        try { writeAndVerify(uri, contents) }
        catch (e: Exception) { runCatching { DocumentsContract.deleteDocument(resolver, uri) }; throw e }
        return uri.toString()
    }

    private fun writeAndVerify(uri: Uri, contents: String) {
        resolver.openOutputStream(uri, "wt")?.use { it.write(contents.toByteArray(Charsets.UTF_8)); it.flush() }
            ?: throw IllegalStateException("Cannot write the backup file.")
        val actual = resolver.openInputStream(uri)?.use { it.readBytes().toString(Charsets.UTF_8) }
            ?: throw IllegalStateException("Cannot verify the saved backup.")
        if (actual != contents) throw IllegalStateException("The backup could not be verified after writing.")
    }

    private fun migrate(parent: Uri) {
        val legacy = File(activity.applicationInfo.dataDir, "app_flutter/twince_backups")
        val files = legacy.listFiles() ?: return
        for (file in files.filter { it.isFile && it.extension.equals("json", true) }) {
            val key = "legacy:${file.absolutePath}"
            if (prefs.contains(key)) continue
            val original = file.readText(Charsets.UTF_8)
            val existing = find(parent, file.name)
            val uri = if (existing != null && runCatching { resolver.openInputStream(existing)?.use { it.readBytes().toString(Charsets.UTF_8) } }.getOrNull() == original) {
                existing.toString()
            } else create(parent, uniqueName(parent, file.name), original)
            if (!prefs.edit().putString(key, uri).commit()) throw IllegalStateException("Could not remember the copied backup; the original remains untouched.")
        }
    }

    companion object { const val REQUEST_FOLDER = 45 }
}
