import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:audiotags/audiotags.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/media_file.dart';

class MetadataService {
  static final MetadataService instance = MetadataService._internal();
  MetadataService._internal();

  Future<MediaFile> extractMetadata(File file, {bool isVideo = false}) async {
    final path = file.path;
    final size = await file.length();
    final addedDate = await file.lastModified();
    final filename = path.split(Platform.pathSeparator).last;
    final dotIndex = filename.lastIndexOf('.');
    final baseName = dotIndex != -1 ? filename.substring(0, dotIndex) : filename;

    // Fallbacks
    String title = baseName;
    String artist = "Unknown Artist";
    String album = "Unknown Album";
    Duration duration = Duration.zero;
    int? bitrate;
    String? albumArtPath;

    // Attempt custom filename parsing: "Artist - Title"
    if (baseName.contains(" - ")) {
      final parts = baseName.split(" - ");
      artist = parts[0].trim();
      title = parts[1].trim();
    }

    try {
      if (isVideo) {
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

        return MediaFile(
          id: path,
          title: title,
          artist: "Video",
          album: "Videos",
          path: path,
          duration: duration,
          isVideo: true,
          size: size,
          addedDate: addedDate,
          resolution: null,
        );
      }

      // Audio metadata extraction (excluding duration to keep scan fast)
      try {
        final metadata = await MetadataRetriever.fromFile(file);

        title = metadata.trackName ?? title;
        artist = metadata.trackArtistNames?.join(", ") ?? metadata.albumArtistName ?? artist;
        album = metadata.albumName ?? album;
        bitrate = metadata.bitrate;

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

      // Fallback 1: AudioTags metadata extraction (safe, does not create AudioPlayer)
      if (title == baseName || artist == "Unknown Artist") {
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
          }
        } catch (e) {
          debugPrint('AudioTags fallback failed for $path: $e');
        }
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
