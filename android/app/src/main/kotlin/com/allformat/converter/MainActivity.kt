package com.allformat.converter

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.allformat.converter/filepicker"
        private const val REQUEST_CODE_PICK_SINGLE = 1001
        private const val REQUEST_CODE_PICK_MULTIPLE = 1002
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingAllowMultiple: Boolean = false

    // ---------------------------------------------------------------------------
    // Flutter Engine setup
    //
    // IMPORTANT: Call GeneratedPluginRegistrant.registerWith() BEFORE setting up
    // custom MethodChannels. This registers all Flutter plugins — including the
    // FFmpegKit event channel (flutter.arthenica.com/ffmpeg_kit_event) — ensuring
    // they are available before any Dart code runs.
    // ---------------------------------------------------------------------------

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Must call super to allow standard auto-registration
        super.configureFlutterEngine(flutterEngine)

        // Then register our custom native file picker channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFiles" -> {
                    pendingResult = result
                    pendingAllowMultiple = call.argument<Boolean>("allowMultiple") ?: false
                    launchPicker()
                }
                else -> result.notImplemented()
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Launch the system file picker using ACTION_OPEN_DOCUMENT (SAF)
    //
    // NO runtime permissions needed — Android grants temporary URI access
    // automatically when the user selects a file in the system picker.
    // ---------------------------------------------------------------------------

    private fun launchPicker() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("video/*", "audio/*", "image/*"))
            if (pendingAllowMultiple) {
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }
        }

        try {
            @Suppress("DEPRECATION")
            startActivityForResult(
                intent,
                if (pendingAllowMultiple) REQUEST_CODE_PICK_MULTIPLE else REQUEST_CODE_PICK_SINGLE,
            )
        } catch (e: Exception) {
            pendingResult?.error("PICKER_ERROR", "Failed to launch file picker: ${e.message}", null)
            pendingResult = null
        }
    }

    // ---------------------------------------------------------------------------
    // Handle result from the system file picker
    // ---------------------------------------------------------------------------

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != REQUEST_CODE_PICK_SINGLE && requestCode != REQUEST_CODE_PICK_MULTIPLE) return

        if (resultCode != RESULT_OK || data == null) {
            pendingResult?.success(null)
            pendingResult = null
            return
        }

        try {
            val uris = mutableListOf<Uri>()

            val clipData = data.clipData
            if (clipData != null) {
                for (i in 0 until clipData.itemCount) {
                    clipData.getItemAt(i).uri?.let { uris.add(it) }
                }
            } else {
                data.data?.let { uris.add(it) }
            }

            if (uris.isEmpty()) {
                pendingResult?.success(null)
                pendingResult = null
                return
            }

            val fileInfoList = uris.mapNotNull { copyUriToCache(it) }
            if (fileInfoList.isNotEmpty()) {
                pendingResult?.success(fileInfoList)
            } else {
                pendingResult?.error("COPY_ERROR", "Could not read any selected files", null)
            }
        } catch (e: Exception) {
            pendingResult?.error("COPY_ERROR", "Error processing files: ${e.message}", null)
        }

        pendingResult = null
    }

    // ---------------------------------------------------------------------------
    // Copy content:// URI to app cache so FFmpeg gets a real file path
    // ---------------------------------------------------------------------------

    private fun copyUriToCache(uri: Uri): Map<String, String>? {
        val displayName = getDisplayName(uri) ?: "unknown_file"

        val cacheDir = File(cacheDir, "picker_cache")
        if (!cacheDir.exists()) cacheDir.mkdirs()

        val targetFile = File(cacheDir, displayName)

        val inputStream = contentResolver.openInputStream(uri) ?: return null
        val outputStream = FileOutputStream(targetFile)

        inputStream.use { input ->
            outputStream.use { output ->
                input.copyTo(output)
            }
        }

        return mapOf(
            "path" to targetFile.absolutePath,
            "name" to displayName,
        )
    }

    private fun getDisplayName(uri: Uri): String? {
        var name: String? = null
        val cursor = contentResolver.query(uri, null, null, null, null)
        cursor?.use {
            if (it.moveToFirst()) {
                val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) {
                    name = it.getString(nameIndex)
                }
            }
        }
        if (name == null) {
            name = uri.lastPathSegment
        }
        return name
    }
}
