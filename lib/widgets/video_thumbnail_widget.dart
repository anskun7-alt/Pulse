import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as legacy_vt;
import 'package:path_provider/path_provider.dart';

/// A robust cross-platform thumbnail widget supporting Windows, Android, iOS, macOS, and Linux:
/// - Uses native Windows Shell / Media Foundation via FcNativeVideoThumbnail.
/// - Caches results in memory AND on disk (survives app restarts).
/// - Deduplicates in-flight generation requests so multiple cards don't compete.
/// - Shows smooth shimmer while generating and graceful fallback on error.
class VideoThumbnailWidget extends StatefulWidget {
  final String videoPath;
  final double width;
  final double height;
  final BoxFit fit;

  const VideoThumbnailWidget({
    Key? key,
    required this.videoPath,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  // Shared in-memory session cache: path → thumbnail file path
  static final Map<String, String> _memCache = {};
  // Deduplicate concurrent extractions for the same video file
  static final Map<String, Future<String?>> _inFlight = {};
  static final FcNativeVideoThumbnail _plugin = FcNativeVideoThumbnail();

  String? _thumbnailPath;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _resolve(widget.videoPath);
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      setState(() => _thumbnailPath = null);
      _resolve(widget.videoPath);
    }
  }

  void _resolve(String videoPath) {
    if (videoPath.isEmpty) return;

    // 1. Instant hit from memory cache
    if (_memCache.containsKey(videoPath)) {
      final cached = _memCache[videoPath]!;
      if (cached.isNotEmpty && File(cached).existsSync()) {
        if (mounted) setState(() => _thumbnailPath = cached);
        return;
      }
      _memCache.remove(videoPath);
    }

    // 2. Kick off async generation
    _startGeneration(videoPath);
  }

  Future<void> _startGeneration(String videoPath) async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // Check if already being extracted by another widget
      Future<String?> future = _inFlight[videoPath] ?? _extractThumbnail(videoPath);
      _inFlight[videoPath] = future;

      final result = await future;
      _inFlight.remove(videoPath);

      if (result != null && result.isNotEmpty) {
        _memCache[videoPath] = result;
        if (mounted) {
          setState(() {
            _thumbnailPath = result;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      _inFlight.remove(videoPath);
      debugPrint('[VideoThumbnail] Extraction error for $videoPath: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  static Future<String?> _extractThumbnail(String videoPath) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final thumbsDir = Directory('${cacheDir.path}${Platform.pathSeparator}video_thumbs');
      if (!await thumbsDir.exists()) {
        await thumbsDir.create(recursive: true);
      }

      final hash = videoPath.hashCode.abs().toString();
      final targetPath = '${thumbsDir.path}${Platform.pathSeparator}thumb_$hash.jpg';
      final targetFile = File(targetPath);

      // Check existing valid disk cache
      if (await targetFile.exists() && await targetFile.length() > 256) {
        return targetPath;
      }

      // 1. Try native platform extractor (Windows, macOS, Android, iOS, Linux)
      try {
        final ok = await _plugin.saveThumbnailToFile(
          srcFile: videoPath,
          destFile: targetPath,
          width: 320,
          height: 240,
          format: 'jpeg',
          quality: 85,
        );
        if (ok && await targetFile.exists() && await targetFile.length() > 256) {
          return targetPath;
        }
      } catch (e) {
        debugPrint('[VideoThumbnail] FcNativeVideoThumbnail failed for $videoPath: $e');
      }

      // 2. Mobile fallback using legacy VideoThumbnail
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          final generatedPath = await legacy_vt.VideoThumbnail.thumbnailFile(
            video: videoPath,
            thumbnailPath: thumbsDir.path,
            imageFormat: legacy_vt.ImageFormat.JPEG,
            maxHeight: 256,
            quality: 80,
          );

          if (generatedPath != null) {
            final genFile = File(generatedPath);
            if (await genFile.exists() && await genFile.length() > 256) {
              if (genFile.path != targetPath) {
                try {
                  await genFile.rename(targetPath);
                } catch (_) {
                  await genFile.copy(targetPath);
                  try { await genFile.delete(); } catch (_) {}
                }
              }
              return targetPath;
            }
          }
        } catch (e) {
          debugPrint('[VideoThumbnail] Legacy fallback failed for $videoPath: $e');
        }
      }
    } catch (e) {
      debugPrint('[VideoThumbnail] General error: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnailPath != null) {
      return Image.file(
        File(_thumbnailPath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: (widget.width > 0 && widget.width.isFinite)
            ? (widget.width * 2).round()
            : null,
        errorBuilder: (context, error, stackTrace) {
          _memCache.remove(widget.videoPath);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _thumbnailPath = null);
              _startGeneration(widget.videoPath);
            }
          });
          return _buildPlaceholder();
        },
      );
    }

    if (_loading) {
      return _buildShimmer();
    }

    return _buildPlaceholder();
  }

  Widget _buildShimmer() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFF1A1A2A),
      child: const _ShimmerBox(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFF1A1A2A),
      child: const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: Color(0xFF3A3A5A),
          size: 32,
        ),
      ),
    );
  }
}

// ─── Shimmer animation ───────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox();

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: const [
                Color(0xFF1A1A2A),
                Color(0xFF2A2A3E),
                Color(0xFF1A1A2A),
              ],
            ),
          ),
        );
      },
    );
  }
}
