package com.pulse.player

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.OpenableColumns
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
  private val CHANNEL = "com.pulse.player/media_intent"
  private var methodChannel: MethodChannel? = null
  private val executor = Executors.newSingleThreadExecutor()
  private val mainHandler = Handler(Looper.getMainLooper())

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    methodChannel?.setMethodCallHandler { call, result ->
      when (call.method) {
        "getInitialFile" -> {
          val path = extractFilePathFromIntent(intent)
          result.success(path)
        }
        "scanMediaStore" -> {
          executor.execute {
            try {
              val mediaList = queryAllMediaStore()
              mainHandler.post { result.success(mediaList) }
            } catch (e: Exception) {
              e.printStackTrace()
              mainHandler.post { result.error("SCAN_ERROR", e.message, null) }
            }
          }
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun queryAllMediaStore(): List<Map<String, Any?>> {
    val results = ArrayList<Map<String, Any?>>()

    // 1. Instant Audio Query
    try {
      val audioProjection = arrayOf(
        MediaStore.Audio.Media._ID,
        MediaStore.Audio.Media.DATA,
        MediaStore.Audio.Media.TITLE,
        MediaStore.Audio.Media.ARTIST,
        MediaStore.Audio.Media.ALBUM,
        MediaStore.Audio.Media.DURATION,
        MediaStore.Audio.Media.SIZE,
        MediaStore.Audio.Media.DATE_MODIFIED,
        MediaStore.Audio.Media.ALBUM_ID
      )
      val audioSelection = "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND ${MediaStore.Audio.Media.IS_RINGTONE} == 0 AND ${MediaStore.Audio.Media.IS_NOTIFICATION} == 0 AND ${MediaStore.Audio.Media.IS_ALARM} == 0 AND ${MediaStore.Audio.Media.DURATION} >= 15000"
      contentResolver.query(
        MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
        audioProjection,
        audioSelection,
        null,
        "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"
      )?.use { cursor ->
        val dataCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
        val titleCol = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
        val artistCol = cursor.getColumnIndex(MediaStore.Audio.Media.ARTIST)
        val albumCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM)
        val durCol = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
        val sizeCol = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)
        val dateCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_MODIFIED)
        val albumIdCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ID)

        while (cursor.moveToNext()) {
          val path = if (dataCol != -1) cursor.getString(dataCol) else null
          if (path.isNullOrEmpty() || !File(path).exists()) continue

          // Exclude system sounds, voice notes, and ringtone paths
          val lowerPath = path.lowercase()
          if (lowerPath.contains("/ringtones/") ||
              lowerPath.contains("/notifications/") ||
              lowerPath.contains("/alarms/") ||
              lowerPath.contains("voice recorder") ||
              lowerPath.contains("/recordings/") ||
              lowerPath.contains("/callrecordings/") ||
              lowerPath.contains("whatsapp voice notes") ||
              lowerPath.contains("whatsapp audio")) {
            continue
          }

          val title = if (titleCol != -1) cursor.getString(titleCol) else null
          val artist = if (artistCol != -1) cursor.getString(artistCol) else null
          val album = if (albumCol != -1) cursor.getString(albumCol) else null
          val duration = if (durCol != -1) cursor.getLong(durCol) else 0L
          val size = if (sizeCol != -1) cursor.getLong(sizeCol) else 0L
          val dateModified = if (dateCol != -1) cursor.getLong(dateCol) else 0L
          val albumId = if (albumIdCol != -1) cursor.getLong(albumIdCol) else -1L

          val artUri = if (albumId > 0) "content://media/external/audio/albumart/$albumId" else null

          val item = HashMap<String, Any?>()
          item["path"] = path
          item["title"] = if (!title.isNullOrBlank()) title else File(path).nameWithoutExtension
          item["artist"] = if (!artist.isNullOrBlank() && artist != "<unknown>") artist else "Unknown Artist"
          item["album"] = if (!album.isNullOrBlank() && album != "<unknown>") album else "Unknown Album"
          item["durationMs"] = duration
          item["size"] = size
          item["dateModifiedSec"] = dateModified
          item["isVideo"] = false
          item["albumArtUri"] = artUri
          results.add(item)
        }
      }
    } catch (e: Exception) {
      e.printStackTrace()
    }

    // 2. Instant Video Query
    try {
      val videoProjection = arrayOf(
        MediaStore.Video.Media._ID,
        MediaStore.Video.Media.DATA,
        MediaStore.Video.Media.TITLE,
        MediaStore.Video.Media.DURATION,
        MediaStore.Video.Media.SIZE,
        MediaStore.Video.Media.DATE_MODIFIED
      )
      val videoSelection = "${MediaStore.Video.Media.DURATION} >= 1000"
      contentResolver.query(
        MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
        videoProjection,
        videoSelection,
        null,
        "${MediaStore.Video.Media.DATE_MODIFIED} DESC"
      )?.use { cursor ->
        val idCol = cursor.getColumnIndex(MediaStore.Video.Media._ID)
        val dataCol = cursor.getColumnIndex(MediaStore.Video.Media.DATA)
        val titleCol = cursor.getColumnIndex(MediaStore.Video.Media.TITLE)
        val durCol = cursor.getColumnIndex(MediaStore.Video.Media.DURATION)
        val sizeCol = cursor.getColumnIndex(MediaStore.Video.Media.SIZE)
        val dateCol = cursor.getColumnIndex(MediaStore.Video.Media.DATE_MODIFIED)

        while (cursor.moveToNext()) {
          val path = if (dataCol != -1) cursor.getString(dataCol) else null
          if (path.isNullOrEmpty() || !File(path).exists()) continue

          val id = if (idCol != -1) cursor.getLong(idCol) else -1L
          val title = if (titleCol != -1) cursor.getString(titleCol) else null
          val duration = if (durCol != -1) cursor.getLong(durCol) else 0L
          val size = if (sizeCol != -1) cursor.getLong(sizeCol) else 0L
          val dateModified = if (dateCol != -1) cursor.getLong(dateCol) else 0L

          val artUri = if (id > 0) "content://media/external/video/media/$id/thumbnail" else null

          val item = HashMap<String, Any?>()
          item["path"] = path
          item["title"] = if (!title.isNullOrBlank()) title else File(path).nameWithoutExtension
          item["artist"] = "Video"
          item["album"] = "Videos"
          item["durationMs"] = duration
          item["size"] = size
          item["dateModifiedSec"] = dateModified
          item["isVideo"] = true
          item["albumArtUri"] = artUri
          results.add(item)
        }
      }
    } catch (e: Exception) {
      e.printStackTrace()
    }

    return results
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    val path = extractFilePathFromIntent(intent) ?: return
    methodChannel?.invokeMethod("onNewFile", path)
  }

  private fun extractFilePathFromIntent(intent: Intent?): String? {
    if (intent == null) return null
    val action = intent.action
    val uri: Uri? = when (action) {
      Intent.ACTION_VIEW -> intent.data
      Intent.ACTION_SEND -> {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
          intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
          @Suppress("DEPRECATION")
          intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
      }
      else -> intent.data
    }

    if (uri == null) return null

    // If it's a file:// scheme
    if (uri.scheme == "file") {
      return uri.path
    }

    // If it's a content:// scheme, try query data path or take permission and return direct URI
    if (uri.scheme == "content") {
      try {
        val flags = intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
        if (flags != 0) {
          contentResolver.takePersistableUriPermission(uri, flags)
        }
      } catch (_: Exception) {}

      try {
        val proj = arrayOf(MediaStore.MediaColumns.DATA)
        contentResolver.query(uri, proj, null, null, null)?.use { cursor ->
          if (cursor.moveToFirst()) {
            val idx = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
            if (idx != -1) {
              val realPath = cursor.getString(idx)
              if (!realPath.isNullOrBlank() && File(realPath).exists()) {
                return realPath
              }
            }
          }
        }
      } catch (_: Exception) {}

      return uri.toString()
    }

    // For HTTP/HTTPS/RTSP streams or other URIs
    return uri.toString()
  }
}
