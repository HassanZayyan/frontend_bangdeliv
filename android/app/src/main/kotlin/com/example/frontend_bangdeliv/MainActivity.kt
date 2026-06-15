package com.example.frontend_bangdeliv

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "bangdeliv/gallery"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImageToGallery" -> saveImageToGallery(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun saveImageToGallery(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        val rawFileName = call.argument<String>("fileName")
        val mimeType = call.argument<String>("mimeType") ?: "image/jpeg"

        if (bytes == null || bytes.isEmpty()) {
            result.error("INVALID_IMAGE", "File QRIS kosong.", null)
            return
        }

        val fileName = sanitizeFileName(rawFileName)
        val resolver = applicationContext.contentResolver
        val imageCollection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    Environment.DIRECTORY_PICTURES + "/BangDeliv"
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val uri = resolver.insert(imageCollection, values)
        if (uri == null) {
            result.error("SAVE_FAILED", "QRIS gagal disimpan ke galeri.", null)
            return
        }

        try {
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
                stream.flush()
            } ?: throw IllegalStateException("Output stream galeri tidak tersedia.")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            }

            result.success(uri.toString())
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            result.error(
                "SAVE_FAILED",
                error.message ?: "QRIS gagal disimpan ke galeri.",
                null
            )
        }
    }

    private fun sanitizeFileName(value: String?): String {
        val fallback = "bangdeliv_qris.jpeg"
        val normalized = value
            ?.trim()
            ?.replace(Regex("[\\\\/:*?\"<>|]"), "_")
            ?.takeIf { it.isNotEmpty() }
            ?: fallback

        return if (normalized.endsWith(".jpeg", true) || normalized.endsWith(".jpg", true)) {
            normalized
        } else {
            "$normalized.jpeg"
        }
    }
}
