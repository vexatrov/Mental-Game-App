package com.mentalgame.mental_game

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

/**
 * Hosts the "mental_game/backup" channel: lets the user pick a backup file
 * once through the system picker (any provider, e.g. Google Drive), keeps
 * permission to it across restarts, and overwrites it on request.
 */
class MainActivity : FlutterActivity() {
    private var pendingPick: MethodChannel.Result? = null
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickTarget" -> pickTarget(
                        call.argument<String>("fileName") ?: "mental-game-backup.json",
                        result,
                    )
                    "write" -> write(
                        call.argument<String>("uri")!!,
                        call.argument<ByteArray>("bytes")!!,
                        result,
                    )
                    "release" -> release(call.argument<String>("uri")!!, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickTarget(fileName: String, result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "The file picker is already open", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/json"
            putExtra(Intent.EXTRA_TITLE, fileName)
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        startActivityForResult(intent, PICK_REQUEST)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_REQUEST) return
        val result = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        val persisted = try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            true
        } catch (e: SecurityException) {
            false
        }
        result.success(
            mapOf(
                "uri" to uri.toString(),
                "name" to (displayName(uri) ?: "Backup file"),
                "persisted" to persisted,
            ),
        )
    }

    private fun displayName(uri: Uri): String? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    } catch (e: Exception) {
        null
    }

    private fun write(uriString: String, bytes: ByteArray, result: MethodChannel.Result) {
        Thread {
            try {
                val uri = Uri.parse(uriString)
                // "wt" truncates; a few providers only accept "w".
                val stream = try {
                    contentResolver.openOutputStream(uri, "wt")
                } catch (e: IllegalArgumentException) {
                    contentResolver.openOutputStream(uri, "w")
                } ?: throw IOException("The backup file could not be opened")
                stream.use { it.write(bytes) }
                main.post { result.success(true) }
            } catch (e: Exception) {
                main.post { result.error("write_failed", e.message ?: e.toString(), null) }
            }
        }.start()
    }

    private fun release(uriString: String, result: MethodChannel.Result) {
        try {
            contentResolver.releasePersistableUriPermission(
                Uri.parse(uriString),
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (e: SecurityException) {
            // Already released or never granted.
        }
        result.success(true)
    }

    companion object {
        private const val CHANNEL = "mental_game/backup"
        private const val PICK_REQUEST = 4242
    }
}
