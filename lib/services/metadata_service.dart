import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:audiotags/audiotags.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import '../models/media_file.dart';

class MetadataService {
  static final MetadataService instance = MetadataService._internal();
  MetadataService._internal();

  /// Removes ugly download prefixes (e.g. YTDown.com_YouTube_) and junk tags
  String cleanTitle(String raw) {
    if (raw.isEmpty) return raw;
    String clean = raw.trim();

    final junkPrefixes = [
      RegExp(r'^ytdown(\.com)?(_youtube)?_', caseSensitive: false),
      RegExp(r'^y2mate(\.is|\.com)?\s*[-_]\s*', caseSensitive: false),
      RegExp(r'^savefrom(\.net)?\s*[-_]\s*', caseSensitive: false),
      RegExp(r'^snapsave(\.app)?\s*[-_]\s*', caseSensitive: false),
      RegExp(r'^ssyoutube(\.com)?\s*[-_]\s*', caseSensitive: false),
      RegExp(r'^\[spotdownloader\.com\]\s*', caseSensitive: false),
      RegExp(r'^\[yt1s(\.com)?\]\s*', caseSensitive: false),
      RegExp(r'^\[yt-dlp\]\s*', caseSensitive: false),
    ];

    for (final pattern in junkPrefixes) {
      clean = clean.replaceFirst(pattern, '');
    }

    final junkSuffixes = [
      RegExp(r'\[(1080p|720p|4k|2160p|hd|full hd)\]', caseSensitive: false),
      RegExp(r'\(?(official\s*(music\s*)?video|official\s*audio|lyrics?|visualizer)\)?', caseSensitive: false),
    ];
    for (final pattern in junkSuffixes) {
      clean = clean.replaceAll(pattern, '');
    }

    if (clean.contains('_') && !clean.contains(' ')) {
      clean = clean.replaceAll('_', ' ');
    }

    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    return clean.isNotEmpty ? clean : raw;
  }

  Future<MediaFile> extractMetadata(File file, {bool isVideo = false}) async {
    final path = file.path;
    final size = await file.length();
    final addedDate = await file.lastModified();
    final filename = path.split(Platform.pathSeparator).last;
    final dotIndex = filename.lastIndexOf('.');
    final baseName = dotIndex != -1 ? filename.substring(0, dotIndex) : filename;

    // Fallbacks
    String title = cleanTitle(baseName);
    String artist = isVideo ? "Video" : "Unknown Artist";
    String album = isVideo ? "Videos" : "Unknown Album";
    Duration duration = Duration.zero;
    int? bitrate;
    String? albumArtPath;

    // Attempt custom filename parsing: "Artist - Title"
    if (!isVideo && baseName.contains(" - ")) {
      final parts = baseName.split(" - ");
      artist = parts[0].trim();
      title = cleanTitle(parts[1].trim());
    }

    try {
      if (isVideo) {
        int realSize = size;
        try {
          if (realSize == 0 && await file.exists()) {
            realSize = await file.length();
          }
        } catch (_) {}

        // Extract video duration using lightweight native MetadataRetriever
        try {
          final metadata = await MetadataRetriever.fromFile(file);
          final durationMs = metadata.trackDuration;
          if (durationMs != null && durationMs > 0) {
            duration = Duration(milliseconds: durationMs);
          }
        } catch (e) {
          debugPrint("Video duration probe failed for $path: $e");
        }

        // Try extracting video thumbnail for notification and UI preview
        try {
          final appDir = await getApplicationSupportDirectory();
          final thumbFile = File('${appDir.path}/vthumb_${path.hashCode}.jpg');
          if (thumbFile.existsSync()) {
            albumArtPath = thumbFile.path;
          } else {
            final thumbOk = await FcNativeVideoThumbnail().saveThumbnailToFile(
              srcFile: path,
              destFile: thumbFile.path,
              width: 320,
              height: 180,
              format: 'jpeg',
              quality: 85,
            );
            if (thumbOk && thumbFile.existsSync()) {
              albumArtPath = thumbFile.path;
            }
          }
        } catch (_) {}

        return MediaFile(
          id: path,
          title: cleanTitle(baseName),
          artist: "Video",
          album: "Videos",
          path: path,
          duration: duration,
          isVideo: true,
          size: realSize,
          addedDate: addedDate,
          resolution: null,
          albumArtPath: albumArtPath,
        );
      }

      // ── Audio metadata extraction ──────────────────────────────────────────
      try {
        final metadata = await MetadataRetriever.fromFile(file);

        title = metadata.trackName ?? title;
        artist = metadata.trackArtistNames?.join(", ") ?? metadata.albumArtistName ?? artist;
        album = metadata.albumName ?? album;
        bitrate = metadata.bitrate;
        if (metadata.trackDuration != null && metadata.trackDuration! > 0) {
          duration = Duration(milliseconds: metadata.trackDuration!);
        }

        // Extract album art to a local file within the app's support directory
        if (metadata.albumArt != null) {
          final appDir = await getApplicationSupportDirectory();
          final artFile = File('${appDir.path}/art_${path.hashCode}.png');
          await artFile.writeAsBytes(metadata.albumArt!);
          albumArtPath = artFile.path;
        }
      } catch (e) {
        debugPrint("Error extracting audio metadata for $path: $e");
      }

      // Fallback: AudioTags metadata extraction
      try {
        final tags = await AudioTags.read(path);
        if (tags != null) {
          if (tags.title != null && tags.title!.isNotEmpty) {
            title = tags.title!;
          }
          if (tags.trackArtist != null && tags.trackArtist!.isNotEmpty) {
            artist = tags.trackArtist!;
          }
          if (tags.album != null && tags.album!.isNotEmpty) {
            album = tags.album!;
          }
          if (duration == Duration.zero && tags.duration != null && tags.duration! > 0) {
            duration = Duration(seconds: tags.duration!);
          }
        }
      } catch (e) {
        debugPrint('AudioTags fallback failed for $path: $e');
      }
    } catch (e) {
      debugPrint("Error reading metadata for $path: $e");
    }

    return MediaFile(
      id: path,
      title: title,
      artist: artist,
      album: album,
      path: path,
      duration: duration,
      isVideo: false,
      size: size,
      addedDate: addedDate,
      bitrate: bitrate,
      albumArtPath: albumArtPath,
    );
  }

  Future<bool> writeTags(String filePath, {
    required String title,
    required String artist,
    required String album,
    String? year,
    String? genre,
    String? trackNumber,
  }) async {
    try {
      final tag = Tag(
        title: title,
        trackArtist: artist,
        album: album,
        year: year != null ? int.tryParse(year) : null,
        genre: genre,
        trackNumber: trackNumber != null ? int.tryParse(trackNumber) : null,
        pictures: [],
      );
      await AudioTags.write(filePath, tag);
      return true;
    } catch (e) {
      debugPrint("Error writing tags to $filePath: $e");
      return false;
    }
  }
}
