package id.sakupro.saku_pro

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileOutputStream

object SakuDownloadStorageHelper {
    private const val SUBFOLDER = "SakuProWann"

    fun saveToDownloads(
        context: Context,
        fileName: String,
        mimeType: String,
        bytes: ByteArray,
        prunePrefix: String? = null,
        maxRetained: Int = 5
    ): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = context.contentResolver
                val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/$SUBFOLDER/"
                val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI

                // Overwrite existing file with the same display name in our subfolder.
                resolver.delete(
                    collection,
                    "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND ${MediaStore.MediaColumns.RELATIVE_PATH}=?",
                    arrayOf(fileName, relativePath)
                )

                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }

                val uri = resolver.insert(collection, values) ?: return null
                resolver.openOutputStream(uri)?.use { stream ->
                    stream.write(bytes)
                    stream.flush()
                }
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)

                if (!prunePrefix.isNullOrEmpty() && maxRetained > 0) {
                    pruneMediaStoreBackups(context, relativePath, prunePrefix, maxRetained)
                }
                "Download/$SUBFOLDER/$fileName"
            } else {
                val baseDir = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                    ?: context.filesDir
                val targetDir = File(baseDir, SUBFOLDER).apply { mkdirs() }
                val outFile = File(targetDir, fileName)
                FileOutputStream(outFile).use { stream ->
                    stream.write(bytes)
                    stream.flush()
                }
                if (!prunePrefix.isNullOrEmpty() && maxRetained > 0) {
                    val matching = targetDir.listFiles { f ->
                        f.isFile && f.name.startsWith(prunePrefix)
                    }?.sortedByDescending { it.lastModified() }.orEmpty()
                    if (matching.size > maxRetained) {
                        for (old in matching.drop(maxRetained)) {
                            old.delete()
                        }
                    }
                }
                outFile.absolutePath
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun pruneMediaStoreBackups(
        context: Context,
        relativePath: String,
        prefix: String,
        maxRetained: Int
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val resolver = context.contentResolver
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DATE_ADDED
        )
        val selection =
            "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND ${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?"
        val args = arrayOf(relativePath, "$prefix%")
        val sortOrder = "${MediaStore.MediaColumns.DATE_ADDED} DESC"

        val idsToDelete = mutableListOf<Long>()
        resolver.query(collection, projection, selection, args, sortOrder)?.use { cursor ->
            var index = 0
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            while (cursor.moveToNext()) {
                if (index >= maxRetained) {
                    idsToDelete.add(cursor.getLong(idCol))
                }
                index++
            }
        }
        for (id in idsToDelete) {
            resolver.delete(ContentUris.withAppendedId(collection, id), null, null)
        }
    }
}
