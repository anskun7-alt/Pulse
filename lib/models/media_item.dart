class MediaItem {
  final String id;
  final String title;
  final String artist;
  final String path;
  final Duration duration;
  final bool isVideo;
  final String? coverUrl;

  const MediaItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.path,
    required this.duration,
    required this.isVideo,
    this.coverUrl,
  });

  String get durationString {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
