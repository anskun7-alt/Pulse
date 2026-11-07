import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/media_file.dart';
import 'media_scanner.dart';
import 'ytdlp_service.dart';

enum DownloadStatus {
  idle,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class MediaQualityOption {
  final String label;
  final String extension;
  final int sizeBytes;
  final StreamInfo? streamInfo;
  final bool isAudioOnly;
  final String? ytdlpFormatId;

  MediaQualityOption({
    required this.label,
    required this.extension,
    required this.sizeBytes,
    this.streamInfo,
    this.isAudioOnly = false,
    this.ytdlpFormatId,
  });

  String get sizeString {
    if (sizeBytes <= 0) return '';
    if (sizeBytes >= 1024 * 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ResolvedPlaylistItem {
  final String id;
  final String title;
  final String author;
  final Duration duration;
  final String thumbnailUrl;
  bool isSelected;

  ResolvedPlaylistItem({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    this.isSelected = true,
  });
}

class ResolvedMediaInfo {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration duration;
  final bool isPlaylist;
  final List<MediaQualityOption> qualityOptions;
  final List<ResolvedPlaylistItem>? playlistVideos;

  ResolvedMediaInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
    this.isPlaylist = false,
    this.qualityOptions = const [],
    this.playlistVideos,
  });
}

class DownloadTask {
  final String id;
  final String url;
  final String fileName;
  final String savePath;
  final String partPath;
  final bool isVideo;
  final String? thumbnailUrl;
  final String? sourceTitle;

  DownloadStatus status;
  int downloadedBytes;
  int totalBytes;
  double speedBytesPerSec;
  String? error;
  DateTime createdAt;

  http.Client? _httpClient;
  StreamSubscription<List<int>>? _streamSub;
  bool _isCancelled = false;
  StreamInfo? _youtubeStreamInfo;
  Process? _ytDlpProcess;
  String? ytdlpFormatId;
  String? originalMediaUrl;
  double? _directProgress;

  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    required this.savePath,
    required this.partPath,
    required this.isVideo,
    this.thumbnailUrl,
    this.sourceTitle,
    this.status = DownloadStatus.idle,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSec = 0.0,
    this.error,
    DateTime? createdAt,
    StreamInfo? youtubeStreamInfo,
    this.ytdlpFormatId,
    this.originalMediaUrl,
  })  : createdAt = createdAt ?? DateTime.now(),
        _youtubeStreamInfo = youtubeStreamInfo;

  double get progress {
    if (_directProgress != null && _directProgress! > 0) return _directProgress!;
    if (totalBytes <= 0) return 0.0;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  String get speedString {
    if (speedBytesPerSec <= 0) return '0 KB/s';
    if (speedBytesPerSec >= 1024 * 1024) {
      return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(speedBytesPerSec / 1024).toStringAsFixed(0)} KB/s';
  }

  String get sizeString {
    String formatSize(int bytes) {
      if (bytes <= 0) return '0 MB';
      if (bytes >= 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
      }
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    if (totalBytes <= 0) return formatSize(downloadedBytes);
    return '${formatSize(downloadedBytes)} / ${formatSize(totalBytes)}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url,
        'fileName': fileName,
        'savePath': savePath,
        'partPath': partPath,
        'isVideo': isVideo,
        'thumbnailUrl': thumbnailUrl,
        'sourceTitle': sourceTitle,
        'status': status.index,
        'downloadedBytes': downloadedBytes,
        'totalBytes': totalBytes,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory DownloadTask.fromMap(Map<dynamic, dynamic> map) => DownloadTask(
        id: map['id'] as String,
        url: map['url'] as String,
        fileName: map['fileName'] as String,
        savePath: map['savePath'] as String,
        partPath: map['partPath'] as String,
        isVideo: map['isVideo'] as bool? ?? true,
        thumbnailUrl: map['thumbnailUrl'] as String?,
        sourceTitle: map['sourceTitle'] as String?,
        status: DownloadStatus.values[(map['status'] as int? ?? 0).clamp(0, DownloadStatus.values.length - 1)],
        downloadedBytes: map['downloadedBytes'] as int? ?? 0,
        totalBytes: map['totalBytes'] as int? ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      );
}

class DownloadService {
  static final DownloadService instance = DownloadService._internal();
  DownloadService._internal();

  final ValueNotifier<List<DownloadTask>> tasks = ValueNotifier<List<DownloadTask>>([]);
  final StreamController<DownloadTask> _onCompletedController = StreamController<DownloadTask>.broadcast();
  Stream<DownloadTask> get onCompletedStream => _onCompletedController.stream;

  late Box _downloadBox;
  bool _initialized = false;
  YoutubeExplode? _yt;

  YoutubeExplode get yt => _yt ??= YoutubeExplode();

  Future<void> init() async {
    if (_initialized) return;
    try {
      _downloadBox = await Hive.openBox('downloads_box');
      _loadSavedTasks();
    } catch (e) {
      debugPrint('[DownloadService] Box init error: $e');
      try {
        await Hive.deleteBoxFromDisk('downloads_box');
        _downloadBox = await Hive.openBox('downloads_box');
      } catch (_) {}
    }
    _initialized = true;
  }

  void _loadSavedTasks() {
    final list = <DownloadTask>[];
    for (var key in _downloadBox.keys) {
      final map = _downloadBox.get(key);
      if (map is Map) {
        final task = DownloadTask.fromMap(map);
        if (task.status == DownloadStatus.downloading) {
          task.status = DownloadStatus.paused;
        }
        list.add(task);
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    tasks.value = list;
  }

  Future<void> _saveTask(DownloadTask task) async {
    try {
      if (_downloadBox.isOpen) {
        await _downloadBox.put(task.id, task.toMap());
      }
    } catch (e) {
      debugPrint('[DownloadService] Failed to save task: $e');
    }
  }

  Future<Directory> getDownloadDir() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/Pulse');
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
          return dir;
        } catch (_) {}
      } else {
        return dir;
      }
    }
    final docDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${docDir.path}/Downloads');
    if (!downloadDir.existsSync()) {
      downloadDir.createSync(recursive: true);
    }
    return downloadDir;
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  bool isYoutubeUrl(String url) {
    final clean = url.trim().toLowerCase();
    return clean.contains('youtube.com') || clean.contains('youtu.be');
  }

  bool isYoutubePlaylistUrl(String url) {
    final clean = url.trim().toLowerCase();
    return (clean.contains('youtube.com') || clean.contains('youtu.be')) && clean.contains('list=');
  }

  /// Resolves any YouTube URL (video or playlist) or direct media URL to metadata and available qualities
  Future<ResolvedMediaInfo> resolveMediaUrl(String url) async {
    final cleanUrl = url.trim();

    // 1. Prefer yt-dlp on desktop platforms for 1080p/4K muxing and multi-platform support
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final isAvailable = await YtDlpService.instance.isYtDlpAvailable();
      if (isAvailable) {
        try {
          return await YtDlpService.instance.resolveMediaUrl(cleanUrl);
        } catch (e) {
          debugPrint('[DownloadService] yt-dlp resolution fallback to pure Dart: $e');
        }
      }
    }

    if (isYoutubePlaylistUrl(cleanUrl)) {
      final playlist = await yt.playlists.get(cleanUrl);
      final videoList = <ResolvedPlaylistItem>[];
      await for (final vid in yt.playlists.getVideos(playlist.id)) {
        videoList.add(ResolvedPlaylistItem(
          id: vid.id.value,
          title: vid.title,
          author: vid.author,
          duration: vid.duration ?? Duration.zero,
          thumbnailUrl: vid.thumbnails.highResUrl,
        ));
      }

      return ResolvedMediaInfo(
        id: playlist.id.value,
        title: playlist.title,
        author: playlist.author,
        thumbnailUrl: playlist.thumbnails.highResUrl,
        duration: Duration.zero,
        isPlaylist: true,
        playlistVideos: videoList,
      );
    }

    if (isYoutubeUrl(cleanUrl)) {
      final video = await yt.videos.get(cleanUrl);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final List<MediaQualityOption> qualityList = [];

      // 1. Muxed streams (Merged Video + Audio - Default choice)
      final muxedStreams = manifest.muxed.sortByVideoQuality();
      bool firstMuxed = true;
      for (final s in muxedStreams) {
        qualityList.add(MediaQualityOption(
          label: firstMuxed
              ? '${s.videoQualityLabel} (Merged Video + Audio) · Default'
              : '${s.videoQualityLabel} (Merged Video + Audio)',
          extension: s.container.name,
          sizeBytes: s.size.totalBytes,
          streamInfo: s,
          isAudioOnly: false,
        ));
        firstMuxed = false;
      }

      // 2. Separate Video Only streams
      final videoOnlyStreams = manifest.videoOnly.sortByVideoQuality();
      for (final s in videoOnlyStreams) {
        if (!qualityList.any((q) => q.label.contains(s.videoQualityLabel))) {
          qualityList.add(MediaQualityOption(
            label: '${s.videoQualityLabel} (Video Only)',
            extension: s.container.name,
            sizeBytes: s.size.totalBytes,
            streamInfo: s,
            isAudioOnly: false,
          ));
        }
      }

      // 3. Separate Audio Only streams
      final audioStreams = manifest.audioOnly.sortByBitrate();
      for (final s in audioStreams) {
        final ext = s.container.name == 'mp4' ? 'm4a' : s.container.name;
        qualityList.add(MediaQualityOption(
          label: '${(s.bitrate.kiloBitsPerSecond).round()} kbps (Audio Only · ${ext.toUpperCase()})',
          extension: ext,
          sizeBytes: s.size.totalBytes,
          streamInfo: s,
          isAudioOnly: true,
        ));
      }

      return ResolvedMediaInfo(
        id: video.id.value,
        title: video.title,
        author: video.author,
        thumbnailUrl: video.thumbnails.highResUrl,
        duration: video.duration ?? Duration.zero,
        isPlaylist: false,
        qualityOptions: qualityList,
      );
    }

    // Direct HTTP/HTTPS Media URL
    final uri = Uri.parse(cleanUrl);
    final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'download_${DateTime.now().millisecondsSinceEpoch}.mp4';

    return ResolvedMediaInfo(
      id: cleanUrl,
      title: fileName,
      author: 'Direct Download',
      thumbnailUrl: '',
      duration: Duration.zero,
      isPlaylist: false,
      qualityOptions: [],
    );
  }

  /// Starts downloading a resolved YouTube stream with quality option
  Future<DownloadTask> startYoutubeDownload({
    required ResolvedMediaInfo info,
    required MediaQualityOption selectedQuality,
    String? customFileName,
  }) async {
    await init();
    final dir = await getDownloadDir();

    var baseName = customFileName != null && customFileName.trim().isNotEmpty
        ? customFileName.trim()
        : info.title;
    baseName = _sanitizeFileName(baseName);

    final ext = selectedQuality.extension;
    final fileName = '$baseName.$ext';
    final savePath = '${dir.path}/$fileName';
    final partPath = '${dir.path}/$fileName.part';

    final id = const Uuid().v4();
    final streamUrl = selectedQuality.streamInfo != null
        ? selectedQuality.streamInfo!.url.toString()
        : info.id;

    final task = DownloadTask(
      id: id,
      url: streamUrl,
      fileName: fileName,
      savePath: savePath,
      partPath: partPath,
      isVideo: !selectedQuality.isAudioOnly,
      thumbnailUrl: info.thumbnailUrl,
      sourceTitle: info.title,
      totalBytes: selectedQuality.sizeBytes,
      status: DownloadStatus.downloading,
      youtubeStreamInfo: selectedQuality.streamInfo,
      ytdlpFormatId: selectedQuality.ytdlpFormatId,
      originalMediaUrl: info.id,
    );

    tasks.value = [task, ...tasks.value];
    await _saveTask(task);

    if (selectedQuality.ytdlpFormatId != null) {
      _executeYtDlpDownload(task, info.id, selectedQuality.isAudioOnly, selectedQuality.ytdlpFormatId);
    } else if (selectedQuality.streamInfo != null) {
      _executeYoutubeDownload(task, selectedQuality.streamInfo!);
    } else {
      _executeDirectDownload(task);
    }
    return task;
  }

  /// Downloads multiple playlist items in batch
  Future<void> startPlaylistDownload({
    required List<ResolvedPlaylistItem> selectedVideos,
    required bool audioOnly,
    String preferredQuality = '720p',
  }) async {
    await init();
    for (final item in selectedVideos) {
      if (!item.isSelected) continue;
      try {
        final manifest = await yt.videos.streamsClient.getManifest(item.id);
        StreamInfo? chosenStream;

        if (audioOnly) {
          chosenStream = manifest.audioOnly.withHighestBitrate();
        } else {
          final sortedMuxed = manifest.muxed.sortByVideoQuality();
          chosenStream = sortedMuxed.firstWhere(
            (s) => s.videoQualityLabel.contains(preferredQuality),
            orElse: () => sortedMuxed.first,
          );
        }

        final dir = await getDownloadDir();
        final ext = chosenStream.container.name == 'mp4' && audioOnly ? 'm4a' : chosenStream.container.name;
        final fileName = '${_sanitizeFileName(item.title)}.$ext';
        final savePath = '${dir.path}/$fileName';
        final partPath = '${dir.path}/$fileName.part';

        final id = const Uuid().v4();
        final task = DownloadTask(
          id: id,
          url: chosenStream.url.toString(),
          fileName: fileName,
          savePath: savePath,
          partPath: partPath,
          isVideo: !audioOnly,
          thumbnailUrl: item.thumbnailUrl,
          sourceTitle: item.title,
          totalBytes: chosenStream.size.totalBytes,
          status: DownloadStatus.downloading,
          youtubeStreamInfo: chosenStream,
        );

        tasks.value = [task, ...tasks.value];
        await _saveTask(task);

        _executeYoutubeDownload(task, chosenStream);
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        debugPrint('Failed to queue playlist item "${item.title}": $e');
      }
    }
  }

  /// Direct generic URL download
  Future<DownloadTask> startDirectDownload(String url, {String? customFileName, bool? isVideo}) async {
    await init();
    final dir = await getDownloadDir();

    var fileName = customFileName != null && customFileName.isNotEmpty
        ? customFileName
        : (Uri.tryParse(url)?.pathSegments.last ?? 'download_${DateTime.now().millisecondsSinceEpoch}.mp4');
    fileName = _sanitizeFileName(fileName);

    final detectedIsVideo = isVideo ?? true;
    final ext = fileName.contains('.') ? fileName.split('.').last : (detectedIsVideo ? 'mp4' : 'mp3');
    if (!fileName.endsWith('.$ext')) {
      fileName = '$fileName.$ext';
    }

    final id = const Uuid().v4();
    final savePath = '${dir.path}/$fileName';
    final partPath = '${dir.path}/$fileName.part';

    final task = DownloadTask(
      id: id,
      url: url,
      fileName: fileName,
      savePath: savePath,
      partPath: partPath,
      isVideo: detectedIsVideo,
      status: DownloadStatus.downloading,
    );

    tasks.value = [task, ...tasks.value];
    await _saveTask(task);

    _executeDirectDownload(task);
    return task;
  }

  Future<void> pauseDownload(String taskId) async {
    final task = tasks.value.firstWhere((t) => t.id == taskId, orElse: () => throw Exception('Task not found'));
    task._isCancelled = true;
    task._httpClient?.close();
    task._streamSub?.cancel();
    if (task._ytDlpProcess != null) {
      task._ytDlpProcess?.kill();
      task._ytDlpProcess = null;
    }
    task.status = DownloadStatus.paused;
    task.speedBytesPerSec = 0.0;
    _notifyUpdate();
    await _saveTask(task);
  }

  Future<void> resumeDownload(String taskId) async {
    final task = tasks.value.firstWhere((t) => t.id == taskId, orElse: () => throw Exception('Task not found'));
    if (task.status == DownloadStatus.downloading) return;

    task.status = DownloadStatus.downloading;
    task.error = null;
    task._isCancelled = false;
    _notifyUpdate();
    await _saveTask(task);

    if (task.ytdlpFormatId != null) {
      _executeYtDlpDownload(task, task.originalMediaUrl ?? task.url, !task.isVideo, task.ytdlpFormatId);
    } else if (task._youtubeStreamInfo != null) {
      _executeYoutubeDownload(task, task._youtubeStreamInfo!);
    } else {
      _executeDirectDownload(task);
    }
  }

  Future<void> retryDownload(String taskId) async {
    await resumeDownload(taskId);
  }

  Future<void> cancelAndDeleteDownload(String taskId) async {
    final task = tasks.value.firstWhere((t) => t.id == taskId, orElse: () => throw Exception('Task not found'));
    task._isCancelled = true;
    task._httpClient?.close();
    task._streamSub?.cancel();
    if (task._ytDlpProcess != null) {
      task._ytDlpProcess?.kill();
      task._ytDlpProcess = null;
    }

    final partFile = File(task.partPath);
    if (partFile.existsSync()) {
      try {
        partFile.deleteSync();
      } catch (_) {}
    }
    final fullFile = File(task.savePath);
    if (fullFile.existsSync()) {
      try {
        fullFile.deleteSync();
      } catch (_) {}
    }

    tasks.value = tasks.value.where((t) => t.id != taskId).toList();
    if (_downloadBox.isOpen) {
      await _downloadBox.delete(taskId);
    }
  }

  void _notifyUpdate() {
    tasks.value = List<DownloadTask>.from(tasks.value);
  }

  Future<void> _executeYtDlpDownload(
    DownloadTask task,
    String mediaUrl,
    bool isAudioOnly,
    String? formatId,
  ) async {
    try {
      final process = await YtDlpService.instance.startDownload(
        url: mediaUrl,
        savePath: task.savePath,
        isAudioOnly: isAudioOnly,
        formatId: formatId,
        onProgress: (progress, speedBytesPerSec, downloaded, total) {
          task._directProgress = progress;
          task.speedBytesPerSec = speedBytesPerSec;
          if (task.totalBytes > 0) {
            task.downloadedBytes = (task.totalBytes * progress).round();
          }
          _notifyUpdate();
        },
        onError: (err) {
          task.status = DownloadStatus.failed;
          task.error = err;
          task.speedBytesPerSec = 0.0;
          _notifyUpdate();
          _saveTask(task);
        },
        onDone: () async {
          await _finalizeCompletedDownload(task);
        },
      );
      task._ytDlpProcess = process;
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString().replaceFirst('Exception: ', '');
      task.speedBytesPerSec = 0.0;
      _notifyUpdate();
      await _saveTask(task);
    }
  }

  Future<String?> _saveThumbnailLocally(String? thumbnailUrl, String mediaPath) async {
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) return null;
    try {
      final thumbFile = File('$mediaPath.thumb.jpg');
      if (thumbFile.existsSync() && thumbFile.lengthSync() > 0) {
        return thumbFile.path;
      }
      final res = await http.get(Uri.parse(thumbnailUrl)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await thumbFile.writeAsBytes(res.bodyBytes);
        return thumbFile.path;
      }
    } catch (e) {
      debugPrint('[DownloadService] Thumbnail cache error: $e');
    }
    return null;
  }

  Future<void> _finalizeCompletedDownload(DownloadTask task) async {
    task.status = DownloadStatus.completed;
    task.speedBytesPerSec = 0.0;
    _notifyUpdate();
    await _saveTask(task);

    String? localThumb;
    if (task.thumbnailUrl != null && task.thumbnailUrl!.isNotEmpty) {
      localThumb = await _saveThumbnailLocally(task.thumbnailUrl, task.savePath);
    }

    try {
      final scanned = await MediaScanner.instance.scanFile(task.savePath);
      if (scanned != null && localThumb != null) {
        final updated = scanned.copyWith(
          albumArtPath: localThumb,
          title: task.sourceTitle != null && task.sourceTitle!.isNotEmpty ? task.sourceTitle! : scanned.title,
        );
        if (_downloadBox.isOpen) {
          final mBox = Hive.box('media_files_box');
          if (mBox.isOpen) {
            await mBox.put(updated.path, updated.toMap());
          }
        }
        final currentList = List<MediaFile>.from(MediaScanner.instance.allFiles.value);
        final idx = currentList.indexWhere((f) => f.path == task.savePath);
        if (idx != -1) {
          currentList[idx] = updated;
          MediaScanner.instance.allFiles.value = currentList;
        }
      }
    } catch (_) {}

    _onCompletedController.add(task);
  }

  Future<void> _executeYoutubeDownload(DownloadTask task, StreamInfo streamInfo) async {
    final partFile = File(task.partPath);
    int existingBytes = 0;
    if (partFile.existsSync()) {
      existingBytes = partFile.lengthSync();
    }
    task.downloadedBytes = existingBytes;

    IOSink? sink;
    try {
      final stream = yt.videos.streamsClient.get(streamInfo);
      sink = partFile.openWrite(mode: FileMode.write); // Streaming write

      int lastSpeedTime = DateTime.now().millisecondsSinceEpoch;
      int bytesSinceLastSpeed = 0;

      await for (final chunk in stream) {
        if (task._isCancelled) break;

        sink.add(chunk);
        task.downloadedBytes += chunk.length;
        bytesSinceLastSpeed += chunk.length;

        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastSpeedTime >= 800) {
          final seconds = (now - lastSpeedTime) / 1000.0;
          task.speedBytesPerSec = bytesSinceLastSpeed / seconds;
          lastSpeedTime = now;
          bytesSinceLastSpeed = 0;
          _notifyUpdate();
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (task._isCancelled) return;

      // Finish download
      final finalFile = File(task.savePath);
      if (finalFile.existsSync()) finalFile.deleteSync();
      await partFile.rename(task.savePath);

      await _finalizeCompletedDownload(task);
    } catch (e) {
      if (!task._isCancelled) {
        task.status = DownloadStatus.failed;
        task.error = e.toString().replaceFirst('Exception: ', '');
        task.speedBytesPerSec = 0.0;
        _notifyUpdate();
        await _saveTask(task);
      }
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
    }
  }

  Future<void> _executeDirectDownload(DownloadTask task) async {
    final partFile = File(task.partPath);
    int existingBytes = 0;
    if (partFile.existsSync()) {
      existingBytes = partFile.lengthSync();
    }
    task.downloadedBytes = existingBytes;

    IOSink? sink;
    task._httpClient = http.Client();

    try {
      final uri = Uri.parse(task.url);
      final request = http.Request('GET', uri);

      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      final response = await task._httpClient!.send(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.statusCode == 206) {
          task.totalBytes = existingBytes + (response.contentLength ?? 0);
        } else {
          if (existingBytes > 0 && response.statusCode == 200) {
            existingBytes = 0;
            partFile.writeAsBytesSync([]);
            task.downloadedBytes = 0;
          }
          task.totalBytes = response.contentLength ?? 0;
        }

        sink = partFile.openWrite(mode: FileMode.append);
        int lastSpeedTime = DateTime.now().millisecondsSinceEpoch;
        int bytesSinceLastSpeed = 0;

        await for (var chunk in response.stream) {
          if (task._isCancelled) break;

          sink.add(chunk);
          task.downloadedBytes += chunk.length;
          bytesSinceLastSpeed += chunk.length;

          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastSpeedTime >= 800) {
            final seconds = (now - lastSpeedTime) / 1000.0;
            task.speedBytesPerSec = bytesSinceLastSpeed / seconds;
            lastSpeedTime = now;
            bytesSinceLastSpeed = 0;
            _notifyUpdate();
          }
        }

        await sink.flush();
        await sink.close();
        sink = null;

        if (task._isCancelled) return;

        final finalFile = File(task.savePath);
        if (finalFile.existsSync()) finalFile.deleteSync();
        await partFile.rename(task.savePath);

        await _finalizeCompletedDownload(task);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (!task._isCancelled) {
        task.status = DownloadStatus.failed;
        task.error = e.toString().replaceFirst('Exception: ', '');
        task.speedBytesPerSec = 0.0;
        _notifyUpdate();
        await _saveTask(task);
      }
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
      task._httpClient?.close();
    }
  }

  MediaFile getPlayableFile(DownloadTask task) {
    final isFinished = task.status == DownloadStatus.completed;
    final filePath = isFinished ? task.savePath : task.partPath;

    return MediaFile(
      id: filePath,
      path: filePath,
      title: task.sourceTitle ?? task.fileName.replaceAll('.part', ''),
      artist: isFinished ? 'Pulse Downloads' : 'Downloading (${task.progressPercent})',
      album: 'Downloads',
      albumArtPath: task.thumbnailUrl,
      isVideo: task.isVideo,
      duration: Duration.zero,
      size: task.downloadedBytes,
      addedDate: task.createdAt,
    );
  }
}
