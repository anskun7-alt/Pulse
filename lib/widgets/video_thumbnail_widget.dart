import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

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
  // In‑memory cache of generated thumbnail paths to avoid file.exists() IO checks on build/rebuilds
  static final Map<String, String> _diskCache = {};
  
  String? _thumbnailPath;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // Synchronous cache check: if already processed in this app session, load instantly (no flashing)
    if (_diskCache.containsKey(widget.videoPath)) {
      final cachedPath = _diskCache[widget.videoPath];
      _thumbnailPath = (cachedPath != null && cachedPath.isNotEmpty) ? cachedPath : null;
    } else {
      _checkCacheAndLoad();
    }
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      if (_diskCache.containsKey(widget.videoPath)) {
        final cachedPath = _diskCache[widget.videoPath];
        _thumbnailPath = (cachedPath != null && cachedPath.isNotEmpty) ? cachedPath : null;
      } else {
        _thumbnailPath = null;
        _checkCacheAndLoad();
      }
    }
  }

  Future<void> _checkCacheAndLoad() async {
    final videoPath = widget.videoPath;
    
    // Check in-memory cache again (safety check for concurrent loads)
    if (_diskCache.containsKey(videoPath)) {
      final cachedPath = _diskCache[videoPath];
      if (cachedPath != null && cachedPath.isNotEmpty) {
        if (mounted) {
          setState(() {
            _thumbnailPath = cachedPath;
          });
        }
        return;
      }
    }

    try {
      final cacheDir = await getTemporaryDirectory();
      // Generate a deterministic unique filename using video path hash
      final hash = videoPath.hashCode.abs().toString();
      final targetPath = '${cacheDir.path}/videothumb_$hash.jpg';
      final targetFile = File(targetPath);

      // If already generated on disk from a previous app run, read it directly
      if (await targetFile.exists()) {
        _diskCache[videoPath] = targetPath;
        if (mounted) {
          setState(() {
            _thumbnailPath = targetPath;
          });
        }
        return;
      }

      // Generate the thumbnail if not already in progress
      if (_isGenerating) return;
      _isGenerating = true;

      final generatedPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: cacheDir.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
      );

      if (generatedPath != null) {
        final genFile = File(generatedPath);
        if (await genFile.exists()) {
          // Rename the generated temporary file to our stable hashed path
          await genFile.rename(targetPath);
          _diskCache[videoPath] = targetPath;
          if (mounted) {
            setState(() {
              _thumbnailPath = targetPath;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error generating video thumbnail: $e');
    } finally {
      _isGenerating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnailPath != null) {
      return Image.file(
        File(_thumbnailPath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Colors.white24,
          size: 48,
        ),
      ),
    );
  }
}
