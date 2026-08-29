import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/media_file.dart';
import '../services/playback_service.dart';
import '../services/media_scanner.dart';
import '../players/video_player_screen.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class ContinuePlayingCard extends StatefulWidget {
  const ContinuePlayingCard({Key? key}) : super(key: key);

  @override
  State<ContinuePlayingCard> createState() => _ContinuePlayingCardState();
}

class _ContinuePlayingCardState extends State<ContinuePlayingCard> {
  bool _isDismissed = false;
  Map<String, dynamic>? _lastPlayed;

  @override
  void initState() {
    super.initState();
    _loadLastPlayed();
  }

  void _loadLastPlayed() {
    try {
      final box = Hive.box('settings_box');
      final path = box.get('last_played_path') as String?;
      if (path != null && path.isNotEmpty) {
        final title = box.get('last_played_title', defaultValue: 'Previous Track') as String;
        final artist = box.get('last_played_artist', defaultValue: 'Unknown Artist') as String;
        final art = box.get('last_played_art', defaultValue: '') as String;
        final posMs = box.get('last_played_position_ms', defaultValue: 0) as int;
        final durMs = box.get('last_played_duration_ms', defaultValue: 0) as int;
        final isVideo = box.get('last_played_is_video', defaultValue: false) as bool;

        if (posMs > 3000) {
          setState(() {
            _lastPlayed = {
              'path': path,
              'title': title,
              'artist': artist,
              'art': art,
              'posMs': posMs,
              'durMs': durMs,
              'isVideo': isVideo,
            };
          });
        }
      }
    } catch (_) {}
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Future<void> _resumePlayback() async {
    if (_lastPlayed == null) return;
    final path = _lastPlayed!['path'] as String;
    final posMs = _lastPlayed!['posMs'] as int;
    final isVideo = _lastPlayed!['isVideo'] as bool;
    final startPos = Duration(milliseconds: posMs);

    // Look up MediaFile in scanner or build instance
    MediaFile? mediaFile;
    try {
      mediaFile = MediaScanner.instance.allFiles.value.firstWhere((f) => f.path == path);
    } catch (_) {
      mediaFile = MediaFile(
        id: path,
        title: _lastPlayed!['title'] as String,
        artist: _lastPlayed!['artist'] as String,
        album: 'Local',
        path: path,
        duration: Duration(milliseconds: _lastPlayed!['durMs'] as int),
        isVideo: isVideo,
        size: 0,
        addedDate: DateTime.now(),
        albumArtPath: _lastPlayed!['art'] as String,
      );
    }

    if (isVideo) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            file: mediaFile!,
            playlist: [mediaFile],
            initialPosition: startPos,
          ),
        ),
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
    if (_isDismissed || _lastPlayed == null) return const SizedBox.shrink();

    return ValueListenableBuilder<MediaFile?>(
      valueListenable: PlaybackService.instance.currentTrack,
      builder: (context, activeTrack, _) {
        if (activeTrack != null) return const SizedBox.shrink();

        final primary = PulseColors.accentPrimary;
        final secondary = PulseColors.accentSecondary;
        final title = _lastPlayed!['title'] as String;
        final artist = _lastPlayed!['artist'] as String;
        final artPath = _lastPlayed!['art'] as String;
        final posMs = _lastPlayed!['posMs'] as int;
        final durMs = _lastPlayed!['durMs'] as int;
        final isVideo = _lastPlayed!['isVideo'] as bool;
        final progress = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withValues(alpha: 0.18),
                      PulseColors.surfaceHigh.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: -2,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Art Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 48,
                            height: 48,
                            color: PulseColors.surface,
                            child: artPath.isNotEmpty && File(artPath).existsSync()
                                ? Image.file(
                                    File(artPath),
                                    fit: BoxFit.cover,
                                    cacheWidth: 120,
                                    cacheHeight: 120,
                                    errorBuilder: (_, __, ___) => Icon(
                                      isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
                                      color: primary,
                                    ),
                                  )
                                : Icon(
                                    isVideo ? Icons.movie_rounded : Icons.music_note_rounded,
                                    color: primary,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Title & Resume Timestamp
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.history_rounded, size: 14, color: secondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Continue ${isVideo ? "Watching" : "Listening"}',
                                    style: TextStyle(
                                      color: secondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PulseTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '$artist · ${_formatDuration(posMs)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PulseTypography.bodySmall.copyWith(
                                  color: PulseColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Resume button
                        ElevatedButton.icon(
                          onPressed: _resumePlayback,
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Resume', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                        ),

                        // Dismiss button
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                          onPressed: () => setState(() => _isDismissed = true),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),

                    // Micro progress bar
                    if (progress > 0) ...[
                      const SizedBox(height: 10),
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
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
      },
    );
  }
}
