import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/media_file.dart';
import '../services/playback_service.dart';
import '../services/media_scanner.dart';
import '../services/metadata_service.dart';
import 'video_thumbnail_widget.dart';
import 'pulse_marquee.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class ContinuePlayingCard extends StatefulWidget {
  const ContinuePlayingCard({Key? key}) : super(key: key);

  @override
  State<ContinuePlayingCard> createState() => _ContinuePlayingCardState();
}

class _ContinuePlayingCardState extends State<ContinuePlayingCard> {
  bool _isDismissed = false;

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Future<void> _resumePlayback(Map<String, dynamic> lastPlayed) async {
    final path = lastPlayed['path'] as String;
    final posMs = lastPlayed['posMs'] as int;
    final isVideo = lastPlayed['isVideo'] as bool;
    final startPos = Duration(milliseconds: posMs);

    // Look up MediaFile in scanner or build fallback instance
    MediaFile? mediaFile;
    try {
      mediaFile = MediaScanner.instance.allFiles.value.firstWhere(
        (f) => f.path.replaceAll('\\', '/').toLowerCase() == path.replaceAll('\\', '/').toLowerCase(),
      );
    } catch (_) {
      mediaFile = MediaFile(
        id: path,
        title: lastPlayed['title'] as String,
        artist: lastPlayed['artist'] as String,
        album: 'Local',
        path: path,
        duration: Duration(milliseconds: lastPlayed['durMs'] as int),
        isVideo: isVideo,
        size: 0,
        addedDate: DateTime.now(),
        albumArtPath: lastPlayed['art'] as String,
      );
    }

    if (isVideo) {
      final videoQueue = MediaScanner.instance.allFiles.value.where((f) => f.isVideo).toList();
      PlaybackService.instance.navigateToVideo(
        videoQueue.isNotEmpty ? videoQueue : [mediaFile],
        mediaFile,
        initialPosition: startPos,
      );
    } else {
      await PlaybackService.instance.playTrack(
        mediaFile,
        startPosition: startPos,
        newQueue: MediaScanner.instance.allFiles.value.where((f) => !f.isVideo).toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final box = Hive.box('settings_box');

    return ValueListenableBuilder<Box>(
      valueListenable: box.listenable(
        keys: [
          'last_played_path',
          'last_played_title',
          'last_played_artist',
          'last_played_art',
          'last_played_position_ms',
          'last_played_duration_ms',
          'last_played_is_video',
        ],
      ),
      builder: (context, box, _) {
        final path = box.get('last_played_path') as String?;
        if (path == null || path.isEmpty) return const SizedBox.shrink();

        final rawTitle = box.get('last_played_title', defaultValue: 'Previous Track') as String;
        final title = MetadataService.instance.cleanTitle(rawTitle);
        final artist = box.get('last_played_artist', defaultValue: 'Unknown Artist') as String;
        final artPath = box.get('last_played_art', defaultValue: '') as String;
        final posMs = box.get('last_played_position_ms', defaultValue: 0) as int;
        final durMs = box.get('last_played_duration_ms', defaultValue: 0) as int;
        final isVideo = box.get('last_played_is_video', defaultValue: false) as bool;
        final progress = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;

        final lastPlayed = {
          'path': path,
          'title': title,
          'artist': artist,
          'art': artPath,
          'posMs': posMs,
          'durMs': durMs,
          'isVideo': isVideo,
        };

        final primary = PulseColors.accentPrimary;
        final secondary = PulseColors.accentSecondary;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withValues(alpha: 0.16),
                      PulseColors.surfaceHigh.withValues(alpha: 0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.12),
                      blurRadius: 18,
                      spreadRadius: -2,
                    )
                  ],
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 38, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 46,
                                  height: 46,
                                  color: PulseColors.surface,
                                  child: isVideo
                                      ? VideoThumbnailWidget(
                                          videoPath: path,
                                          width: 46,
                                          height: 46,
                                          fit: BoxFit.cover,
                                        )
                                      : (artPath.isNotEmpty && File(artPath).existsSync()
                                          ? Image.file(
                                              File(artPath),
                                              fit: BoxFit.cover,
                                              cacheWidth: 120,
                                              cacheHeight: 120,
                                              errorBuilder: (_, __, ___) => Icon(
                                                Icons.music_note_rounded,
                                                color: primary,
                                              ),
                                            )
                                          : Icon(
                                              Icons.music_note_rounded,
                                              color: primary,
                                            )),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.history_rounded, size: 13, color: secondary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Continue ${isVideo ? "Watching" : "Listening"}',
                                          style: TextStyle(
                                            color: secondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    PulseMarqueeText(
                                      text: title,
                                      style: PulseTypography.bodyLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      posMs > 0 ? '$artist · ${_formatDuration(posMs)}' : artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: PulseTypography.bodySmall.copyWith(
                                        color: PulseColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _resumePlayback(lastPlayed),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [primary, primary.withValues(alpha: 0.85)],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primary.withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          'Resume',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Micro progress bar
                          if (progress > 0) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 3,
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(secondary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Top-right dismiss button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                        onPressed: () => setState(() => _isDismissed = true),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        tooltip: 'Dismiss',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
      },
    );
  }
}
