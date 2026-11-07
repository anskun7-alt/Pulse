import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'download_service.dart';

class YtDlpService {
  static final YtDlpService instance = YtDlpService._internal();
  YtDlpService._internal();

  String? _cachedYtDlpPath;
  String? _cachedFfmpegPath;

  /// Known common directories on Windows (project-bundled tools prioritized)
  static const List<String> _candidateYtDlpPaths = [
    r'tools\bin\yt-dlp.exe',
    r'e:\GMWF\media_player\tools\bin\yt-dlp.exe',
    r'C:\yt-dlp\yt-dlp.exe',
    r'C:\yt-dlp.exe',
    r'C:\tools\yt-dlp\yt-dlp.exe',
  ];

  static const List<String> _candidateFfmpegPaths = [
    r'tools\bin\ffmpeg.exe',
    r'e:\GMWF\media_player\tools\bin\ffmpeg.exe',
    r'C:\ffmpeg\bin\ffmpeg.exe',
    r'C:\ffmpeg\ffmpeg.exe',
    r'C:\tools\ffmpeg\bin\ffmpeg.exe',
  ];

  /// Find yt-dlp executable path
  Future<String?> getYtDlpPath({bool forceRefresh = false}) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return null;
    if (!forceRefresh && _cachedYtDlpPath != null) return _cachedYtDlpPath;

    // 1. Check user custom setting in Hive
    try {
      if (Hive.isBoxOpen('settings_box')) {
        final box = Hive.box('settings_box');
        final custom = box.get('ytdlp_path') as String?;
        if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
          _cachedYtDlpPath = custom;
          return custom;
        }
      }
    } catch (_) {}

    // 2. Check project folder and predefined local paths
    for (final candidate in _candidateYtDlpPaths) {
      final file = File(candidate);
      if (file.existsSync()) {
        _cachedYtDlpPath = file.absolute.path;
        return file.absolute.path;
      }
    }

    // 3. Check App Directory
    try {
      final appDir = p.dirname(Platform.resolvedExecutable);
      final bundled = p.join(appDir, 'tools', 'bin', 'yt-dlp.exe');
      if (File(bundled).existsSync()) {
        _cachedYtDlpPath = bundled;
        return bundled;
      }
      final appDirExe = p.join(appDir, 'yt-dlp.exe');
      if (File(appDirExe).existsSync()) {
        _cachedYtDlpPath = appDirExe;
        return appDirExe;
      }
    } catch (_) {}

    // 4. Check system PATH
    try {
      final result = await Process.run('where.exe', ['yt-dlp.exe'], runInShell: true);
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final lines = result.stdout.toString().trim().split(RegExp(r'[\r\n]+'));
        if (lines.isNotEmpty && File(lines.first).existsSync()) {
          _cachedYtDlpPath = lines.first;
          return lines.first;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Find ffmpeg executable path
  Future<String?> getFfmpegPath({bool forceRefresh = false}) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return null;
    if (!forceRefresh && _cachedFfmpegPath != null) return _cachedFfmpegPath;

    // 1. Check user custom setting in Hive
    try {
      if (Hive.isBoxOpen('settings_box')) {
        final box = Hive.box('settings_box');
        final custom = box.get('ffmpeg_path') as String?;
        if (custom != null && custom.isNotEmpty && File(custom).existsSync()) {
          _cachedFfmpegPath = custom;
          return custom;
        }
      }
    } catch (_) {}

    // 2. Check project folder and predefined local paths
    for (final candidate in _candidateFfmpegPaths) {
      final file = File(candidate);
      if (file.existsSync()) {
        _cachedFfmpegPath = file.absolute.path;
        return file.absolute.path;
      }
    }

    // 3. Check App Directory
    try {
      final appDir = p.dirname(Platform.resolvedExecutable);
      final bundled = p.join(appDir, 'tools', 'bin', 'ffmpeg.exe');
      if (File(bundled).existsSync()) {
        _cachedFfmpegPath = bundled;
        return bundled;
      }
      final appDirExe = p.join(appDir, 'ffmpeg.exe');
      if (File(appDirExe).existsSync()) {
        _cachedFfmpegPath = appDirExe;
        return appDirExe;
      }
    } catch (_) {}

    // 4. Check system PATH
    try {
      final result = await Process.run('where.exe', ['ffmpeg.exe'], runInShell: true);
      if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
        final lines = result.stdout.toString().trim().split(RegExp(r'[\r\n]+'));
        if (lines.isNotEmpty && File(lines.first).existsSync()) {
          _cachedFfmpegPath = lines.first;
          return lines.first;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<bool> isYtDlpAvailable() async {
    final path = await getYtDlpPath();
    return path != null;
  }

  Future<bool> isFfmpegAvailable() async {
    final path = await getFfmpegPath();
    return path != null;
  }

  /// Probes media URL using yt-dlp --dump-json
  Future<ResolvedMediaInfo> resolveMediaUrl(String url) async {
    final ytPath = await getYtDlpPath();
    if (ytPath == null) {
      throw Exception('yt-dlp executable not found');
    }

    final args = <String>[
      '--dump-single-json',
      '--flat-playlist',
      '--no-warnings',
      '--skip-download',
    ];

    final ffmpegPath = await getFfmpegPath();
    if (ffmpegPath != null) {
      args.addAll(['--ffmpeg-location', p.dirname(ffmpegPath)]);
    }
    args.add(url.trim());

    debugPrint('[YtDlpService] Probing: $ytPath ${args.join(" ")}');
    final result = await Process.run(ytPath, args, stdoutEncoding: utf8, stderrEncoding: utf8);

    if (result.exitCode != 0) {
      final error = result.stderr.toString().trim();
      throw Exception(error.isNotEmpty ? error : 'yt-dlp probe failed with exit code ${result.exitCode}');
    }

    final rawJson = result.stdout.toString().trim();
    if (rawJson.isEmpty) {
      throw Exception('No media metadata returned from yt-dlp');
    }

    final Map<String, dynamic> data = json.decode(rawJson);

    final title = data['title'] as String? ?? 'Media Stream';
    final uploader = data['uploader'] as String? ?? data['channel'] as String? ?? 'Online Media';
    final id = data['id'] as String? ?? url;
    final durationSeconds = (data['duration'] as num?)?.toInt() ?? 0;
    final duration = Duration(seconds: durationSeconds);
    final thumbnail = data['thumbnail'] as String? ?? '';

    // Check if playlist
    if (data['_type'] == 'playlist' || data['entries'] is List) {
      final entries = data['entries'] as List? ?? [];
      final playlistItems = <ResolvedPlaylistItem>[];
      for (final entry in entries) {
        if (entry is Map) {
          final vidId = entry['id'] as String? ?? '';
          final vidTitle = entry['title'] as String? ?? 'Video';
          final vidAuthor = entry['uploader'] as String? ?? uploader;
          final vidDur = Duration(seconds: (entry['duration'] as num?)?.toInt() ?? 0);
          final vidThumb = entry['thumbnail'] as String? ?? thumbnail;
          playlistItems.add(ResolvedPlaylistItem(
            id: vidId,
            title: vidTitle,
            author: vidAuthor,
            duration: vidDur,
            thumbnailUrl: vidThumb,
          ));
        }
      }

      return ResolvedMediaInfo(
        id: id,
        title: title,
        author: uploader,
        thumbnailUrl: thumbnail,
        duration: duration,
        isPlaylist: true,
        playlistVideos: playlistItems,
      );
    }

    // Parse formats for single video
    final qualityList = <MediaQualityOption>[];
    final formats = (data['formats'] as List?)?.cast<Map<dynamic, dynamic>>() ?? [];

    // Distinct resolutions seen
    final seenResolutions = <int>{};

    // 1. Video options (sorted highest resolution first)
    final videoFormats = formats.where((f) => f['vcodec'] != 'none' && f['height'] != null).toList()
      ..sort((a, b) => ((b['height'] as num?) ?? 0).compareTo((a['height'] as num?) ?? 0));

    for (final f in videoFormats) {
      final h = (f['height'] as num?)?.toInt() ?? 0;
      if (h <= 0 || seenResolutions.contains(h)) continue;
      seenResolutions.add(h);

      final formatId = f['format_id']?.toString() ?? '';
      final fps = f['fps'] != null ? '${f['fps']}fps' : '';
      final size = (f['filesize'] as num?)?.toInt() ?? (f['filesize_approx'] as num?)?.toInt() ?? 0;

      String label = '${h}p';
      if (h >= 2160) {
        label = '4K (2160p)';
      } else if (h >= 1440) {
        label = '2K (1440p)';
      } else if (h >= 1080) {
        label = 'Full HD (1080p)';
      } else if (h >= 720) {
        label = 'HD (720p)';
      }
      if (fps.isNotEmpty) label += ' $fps';

      qualityList.add(MediaQualityOption(
        label: label,
        extension: 'mp4',
        sizeBytes: size,
        isAudioOnly: false,
        ytdlpFormatId: formatId,
      ));
    }

    // 2. Audio only options
    final audioFormats = formats.where((f) => f['vcodec'] == 'none' && (f['acodec'] != 'none' || f['abr'] != null)).toList()
      ..sort((a, b) => ((b['abr'] as num?) ?? 0).compareTo((a['abr'] as num?) ?? 0));

    final bestAudioSize = audioFormats.isNotEmpty
        ? ((audioFormats.first['filesize'] as num?)?.toInt() ?? (audioFormats.first['filesize_approx'] as num?)?.toInt() ?? 0)
        : 0;

    qualityList.add(MediaQualityOption(
      label: 'Best Audio (MP3 • 320kbps)',
      extension: 'mp3',
      sizeBytes: bestAudioSize,
      isAudioOnly: true,
      ytdlpFormatId: 'bestaudio',
    ));

    return ResolvedMediaInfo(
      id: id,
      title: title,
      author: uploader,
      thumbnailUrl: thumbnail,
      duration: duration,
      isPlaylist: false,
      qualityOptions: qualityList,
    );
  }

  /// Spawns yt-dlp to download with live stdout progress reporting
  Future<Process> startDownload({
    required String url,
    required String savePath,
    bool isAudioOnly = false,
    String? formatId,
    required void Function(double progress, double speedBytesPerSec, int downloadedBytes, int totalBytes) onProgress,
    required void Function(String error) onError,
    required void Function() onDone,
  }) async {
    final ytPath = await getYtDlpPath();
    if (ytPath == null) throw Exception('yt-dlp executable not found');

    final ffmpegPath = await getFfmpegPath();
    final args = <String>[
      '--newline',
      '--no-playlist',
      '--no-part',
      '-o', savePath,
    ];

    if (ffmpegPath != null) {
      args.addAll(['--ffmpeg-location', p.dirname(ffmpegPath)]);
    }

    if (isAudioOnly) {
      args.addAll([
        '-x',
        '--audio-format', 'mp3',
        '--audio-quality', '0',
        '--embed-thumbnail',
        '--embed-metadata',
      ]);
    } else {
      if (formatId != null && formatId.isNotEmpty) {
        args.addAll(['-f', '$formatId+bestaudio/best', '--merge-output-format', 'mp4']);
      } else {
        args.addAll(['-f', 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best', '--merge-output-format', 'mp4']);
      }
    }

    args.add(url.trim());
    debugPrint('[YtDlpService] Executing: $ytPath ${args.join(" ")}');

    final process = await Process.start(ytPath, args);

    // Regex for yt-dlp progress: [download]  45.2% of 25.30MiB at  2.34MiB/s
    final percentRegex = RegExp(r'(\d+\.?\d*)%');
    final speedRegex = RegExp(r'at\s+(\d+\.?\d*)([KkMmGg]i?B)/s');

    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      debugPrint('[yt-dlp] $line');
      final percentMatch = percentRegex.firstMatch(line);
      if (percentMatch != null) {
        final percent = double.tryParse(percentMatch.group(1) ?? '0') ?? 0.0;
        final progress = (percent / 100.0).clamp(0.0, 1.0);

        double speed = 0.0;
        final speedMatch = speedRegex.firstMatch(line);
        if (speedMatch != null) {
          final numVal = double.tryParse(speedMatch.group(1) ?? '0') ?? 0.0;
          final unit = (speedMatch.group(2) ?? 'KiB').toUpperCase();
          if (unit.contains('M')) {
            speed = numVal * 1024 * 1024;
          } else if (unit.contains('K')) {
            speed = numVal * 1024;
          } else if (unit.contains('G')) {
            speed = numVal * 1024 * 1024 * 1024;
          }
        }

        onProgress(progress, speed, 0, 0);
      }
    });

    final errorBuffer = StringBuffer();
    process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      errorBuffer.writeln(line);
      debugPrint('[yt-dlp stderr] $line');
    });

    process.exitCode.then((code) {
      if (code == 0) {
        onDone();
      } else {
        final err = errorBuffer.toString().trim();
        onError(err.isNotEmpty ? err : 'Download failed with exit code $code');
      }
    });

    return process;
  }
}
