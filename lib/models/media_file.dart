class MediaFile {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final Duration duration;
  final bool isVideo;
  final int size; // in bytes
  final DateTime addedDate;
  final String? resolution;
  final int? bitrate;
  final String? albumArtPath;
  final bool isFavorite;

  const MediaFile({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.duration,
    required this.isVideo,
    required this.size,
    required this.addedDate,
    this.resolution,
    this.bitrate,
    this.albumArtPath,
    this.isFavorite = false,
  });

  String get durationString {
    if (duration == Duration.zero) return '--:--';
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get sizeString {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  MediaFile copyWith({
    String? title,
    String? artist,
    String? album,
    String? path,
    Duration? duration,
    bool? isVideo,
    int? size,
    DateTime? addedDate,
    String? resolution,
    int? bitrate,
    String? albumArtPath,
    bool? isFavorite,
  }) {
    return MediaFile(
      id: this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      path: path ?? this.path,
      duration: duration ?? this.duration,
      isVideo: isVideo ?? this.isVideo,
      size: size ?? this.size,
      addedDate: addedDate ?? this.addedDate,
      resolution: resolution ?? this.resolution,
      bitrate: bitrate ?? this.bitrate,
      albumArtPath: albumArtPath ?? this.albumArtPath,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  // Caching serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'path': path,
      'durationMs': duration.inMilliseconds,
      'isVideo': isVideo,
      'size': size,
      'addedDate': addedDate.millisecondsSinceEpoch,
      'resolution': resolution,
      'bitrate': bitrate,
      'albumArtPath': albumArtPath,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory MediaFile.fromMap(Map<dynamic, dynamic> map) {
    return MediaFile(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      artist: map['artist']?.toString() ?? '',
      album: map['album']?.toString() ?? '',
      path: map['path']?.toString() ?? '',
      duration: Duration(milliseconds: (map['durationMs'] is num ? (map['durationMs'] as num).toInt() : 0)),
      isVideo: map['isVideo'] as bool? ?? false,
      size: map['size'] is num ? (map['size'] as num).toInt() : 0,
      addedDate: map['addedDate'] != null ? DateTime.fromMillisecondsSinceEpoch((map['addedDate'] is num ? (map['addedDate'] as num).toInt() : 0)) : DateTime.fromMillisecondsSinceEpoch(0),
      resolution: map['resolution']?.toString(),
      bitrate: map['bitrate'] is num ? (map['bitrate'] as num).toInt() : null,
      albumArtPath: map['albumArtPath']?.toString(),
      isFavorite: (map['isFavorite'] ?? 0) == 1,
    );
  }
}
