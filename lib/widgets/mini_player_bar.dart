import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../services/playback_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../players/audio_player_screen.dart';
import '../players/video_player_screen.dart';
import 'video_thumbnail_widget.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final playbackService = PlaybackService.instance;

    return ValueListenableBuilder<MediaFile?>(
      valueListenable: playbackService.currentTrack,
      builder: (context, track, child) {
        if (track == null || playbackService.videoScreenOpen) return const SizedBox.shrink();

        final bottomPad = MediaQuery.of(context).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, bottom: 8 + bottomPad),
          child: GestureDetector(
            onTap: () {
              if (track.isVideo) {
                final currentPosition = playbackService.position.value;
                playbackService.player.pause();
                
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(
                      file: track,
                      playlist: playbackService.queue.value,
                      initialPosition: currentPosition,
                    ),
                  ),
                );
              } else {
                if (PlaybackService.instance.audioScreenOpen) return;
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const AudioPlayerScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      final tween =
                          Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                              .chain(CurveTween(
                                  curve: Curves.fastLinearToSlowEaseIn));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                  ),
                );
              }
            },
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! < 0) {
                  playbackService.next();
                } else if (details.primaryVelocity! > 0) {
                  playbackService.previous();
                }
              }
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! > 0) {
                playbackService.dismissMiniPlayer();
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF12121E).withValues(alpha: 0.85),
                        const Color(0xFF1E1E30).withValues(alpha: 0.65),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF1E1E30).withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            const SizedBox(width: 10),
                            // Album art
                            Hero(
                              tag: 'mini_album_art_${track.path}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _AudioArtWidget(
                                  artPath: track.albumArtPath,
                                  size: 48,
                                  fallbackIconSize: 24,
                                  track: track,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Track info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: PulseTypography.bodyLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: PulseTypography.bodyMedium.copyWith(
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Controls
                            ValueListenableBuilder<bool>(
                              valueListenable: playbackService.isLoading,
                              builder: (context, isLoading, child) {
                                return ValueListenableBuilder<bool>(
                                  valueListenable: playbackService.isPlaying,
                                  builder: (context, playing, child) {
                                    final accentColor = track.isVideo
                                        ? const Color(0xFF00E5FF)
                                        : const Color(0xFFFF9100);
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Previous track
                                        _AnimatedTapScale(
                                          onTap: () => playbackService.previous(),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              Icons.skip_previous_rounded,
                                              color: Colors.white.withValues(alpha: 0.9),
                                              size: 26,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        // Play / Pause
                                        isLoading
                                            ? Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: accentColor,
                                                  ),
                                                ),
                                              )
                                            : _AnimatedTapScale(
                                                onTap: () => playbackService.togglePlay(),
                                                child: Icon(
                                                  playing
                                                      ? Icons.pause_circle_filled_rounded
                                                      : Icons.play_circle_filled_rounded,
                                                  color: accentColor,
                                                  size: 44,
                                                ),
                                              ),
                                        const SizedBox(width: 4),
                                        // Next track
                                        _AnimatedTapScale(
                                          onTap: () => playbackService.next(),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Icon(
                                              Icons.skip_next_rounded,
                                              color: Colors.white.withValues(alpha: 0.9),
                                              size: 26,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Bottom glowing neon progress bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 3,
                        child: ValueListenableBuilder<Duration>(
                          valueListenable: playbackService.position,
                          builder: (context, pos, _) {
                            return ValueListenableBuilder<Duration>(
                              valueListenable: playbackService.duration,
                              builder: (context, dur, _) {
                                final totalMs = dur.inMilliseconds;
                                final currentMs = pos.inMilliseconds;
                                final double ratio = totalMs > 0 ? (currentMs / totalMs).clamp(0.0, 1.0) : 0.0;
                                final accentColor = track.isVideo
                                    ? const Color(0xFF00E5FF)
                                    : const Color(0xFFFF9100);
                                return FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: ratio,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentColor.withValues(alpha: 0.8),
                                          blurRadius: 8,
                                          spreadRadius: 1.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AudioArtWidget extends StatelessWidget {
  final String? artPath;
  final double size;
  final double fallbackIconSize;
  final MediaFile? track;

  const _AudioArtWidget({
    required this.artPath,
    required this.size,
    required this.fallbackIconSize,
    this.track,
  });

  @override
  Widget build(BuildContext context) {
    if (track != null && track!.isVideo) {
      return VideoThumbnailWidget(
        videoPath: track!.path,
        width: size,
        height: size,
      );
    }
    if (artPath != null && artPath!.isNotEmpty) {
      return Image.file(
        File(artPath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      color: PulseColors.surfaceHigh,
      child: Icon(
        Icons.music_note_rounded,
        color: PulseColors.accentPrimary,
        size: fallbackIconSize,
      ),
    );
  }
}

class _AnimatedTapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedTapScale({
    Key? key,
    required this.child,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_AnimatedTapScale> createState() => _AnimatedTapScaleState();
}

class _AnimatedTapScaleState extends State<_AnimatedTapScale> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}