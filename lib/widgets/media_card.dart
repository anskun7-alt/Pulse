import 'dart:io';
import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'video_thumbnail_widget.dart';
import '../services/playback_service.dart';

class MediaCard extends StatelessWidget {
  final MediaFile file;
  final bool isGrid;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;
  // When true, renders a checkbox overlay and uses selection-mode tap behaviour.
  final bool isSelectionMode;
  final VoidCallback? onMore;

  const MediaCard({
    Key? key,
    required this.file,
    required this.isGrid,
    required this.onTap,
    required this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onMore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isGrid) {
      return _buildGridCard(context);
    }
    return _buildListCard(context);
  }

  // ─── Grid card ────────────────────────────────────────────────────────────
  Widget _buildGridCard(BuildContext context) {
    return ValueListenableBuilder<MediaFile?>(
      valueListenable: PlaybackService.instance.currentTrack,
      builder: (context, currentTrack, _) {
        final isCurrent = currentTrack?.path == file.path;
        final accentColor = file.isVideo ? const Color(0xFF00E5FF) : const Color(0xFFFF9100);

        return GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withValues(alpha: 0.8),
                            Colors.transparent,
                            accentColor.withValues(alpha: 0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: isCurrent 
                            ? [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                )
                              ]
                            : PulseColors.glowShadow(accentColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(1.2),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C0C14),
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(19),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                RepaintBoundary(
                                  child: file.isVideo
                                      ? _buildThumbnail()
                                      : ValueListenableBuilder<bool>(
                                          valueListenable: PlaybackService.instance.isPlaying,
                                          builder: (context, isPlaying, _) {
                                            final isSpinning = isCurrent && isPlaying;
                                            
                                            final thumbnailChild = file.albumArtPath != null && file.albumArtPath!.isNotEmpty
                                                ? Image.file(
                                                    File(file.albumArtPath!),
                                                    fit: BoxFit.cover,
                                                    cacheWidth: 300,
                                                    cacheHeight: 300,
                                                    errorBuilder: (context, error, stackTrace) => _buildPlaceholder(48),
                                                )
                                                : _buildPlaceholder(48);

                                            return SpinningThumbnail(
                                              isSpinning: isSpinning,
                                              child: thumbnailChild,
                                            );
                                          },
                                        ),
                                ),
                                // Gradient overlay
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.65),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ),
                                // Duration badge
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      file.durationString,
                                      style: PulseTypography.monoLabel.copyWith(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                if (file.isVideo)
                                  const Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Icon(
                                      Icons.play_circle_filled_rounded,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ── Selection overlay ──────────────────────────────────────
                    if (isSelectionMode)
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: isSelected
                                ? PulseColors.accentSecondary.withValues(alpha: 0.28)
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? PulseColors.accentSecondary
                                  : Colors.white30,
                              width: isSelected ? 2.5 : 1.0,
                            ),
                          ),
                        ),
                      ),
                    if (isSelectionMode)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _SelectionCheckbox(selected: isSelected),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            file.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PulseTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? accentColor : null,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 6),
                          file.isVideo
                              ? _PulsingIndicatorLight(color: accentColor)
                              : ValueListenableBuilder<bool>(
                                  valueListenable: PlaybackService.instance.isPlaying,
                                  builder: (_, isPlaying, __) => EqualizerBarsIndicator(
                                    color: accentColor,
                                    isAnimating: isPlaying,
                                  ),
                                ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${file.sizeString} · ${file.isVideo ? "Video" : file.artist}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PulseTypography.monoLabel.copyWith(
                        color: isCurrent ? accentColor.withValues(alpha: 0.7) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── List card ────────────────────────────────────────────────────────────
  Widget _buildListCard(BuildContext context) {
    final double thumbWidth = file.isVideo ? 100 : 60;
    final double thumbHeight = file.isVideo ? 58 : 60;

    return ValueListenableBuilder<MediaFile?>(
      valueListenable: PlaybackService.instance.currentTrack,
      builder: (context, currentTrack, _) {
        final isCurrent = currentTrack?.path == file.path;
        final accentColor = file.isVideo ? const Color(0xFF00E5FF) : const Color(0xFFFF9100);

        return InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: isSelected
                  ? PulseColors.accentSecondary.withValues(alpha: 0.12)
                  : (isCurrent ? accentColor.withValues(alpha: 0.06) : Colors.transparent),
              border: Border.all(
                color: isSelected
                    ? PulseColors.accentSecondary.withValues(alpha: 0.5)
                    : (isCurrent ? accentColor.withValues(alpha: 0.3) : Colors.transparent),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Row(
                children: [
                  // ── Selection checkbox in list mode ──────────────────────────
                  if (isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _SelectionCheckbox(selected: isSelected),
                    ),

                  // Thumbnail with duration overlay
                  Container(
                    width: thumbWidth,
                    height: thumbHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: file.isFavorite || isCurrent
                          ? [
                              BoxShadow(
                                color: (file.isFavorite ? PulseColors.accentPrimary : accentColor).withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          file.isVideo
                              ? VideoThumbnailWidget(
                                  videoPath: file.path,
                                  width: thumbWidth,
                                  height: thumbHeight,
                                )
                              : ValueListenableBuilder<bool>(
                                  valueListenable: PlaybackService.instance.isPlaying,
                                  builder: (context, isPlaying, _) {
                                    final isSpinning = isCurrent && isPlaying;
                                    
                                    final thumbnailChild = file.albumArtPath != null && file.albumArtPath!.isNotEmpty
                                        ? Image.file(
                                            File(file.albumArtPath!),
                                            fit: BoxFit.cover,
                                            cacheWidth: 160,
                                            cacheHeight: 160,
                                            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(28),
                                          )
                                        : _buildPlaceholder(28);

                                    return SpinningThumbnail(
                                      isSpinning: isSpinning,
                                      child: thumbnailChild,
                                    );
                                  },
                                ),
                          if (file.isVideo && file.duration > Duration.zero)
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  file.durationString,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Title & subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                file.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PulseTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isCurrent ? accentColor : null,
                                ),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              file.isVideo
                                  ? _PulsingIndicatorLight(color: accentColor)
                                  : ValueListenableBuilder<bool>(
                                      valueListenable: PlaybackService.instance.isPlaying,
                                      builder: (_, isPlaying, __) => EqualizerBarsIndicator(
                                        color: accentColor,
                                        isAnimating: isPlaying,
                                      ),
                                    ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          file.isVideo
                              ? _getFolderName(file.path)
                              : '${file.artist} · ${file.album}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                        if (file.isVideo) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${file.sizeString} · ${_formatDate(file.addedDate)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Context More Menu Button
                  if (onMore != null)
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.white60),
                      onPressed: onMore,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  else if (!file.isVideo)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          file.durationString,
                          style: PulseTypography.monoLabel.copyWith(
                            color: isCurrent ? accentColor : PulseColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (file.isFavorite)
                          const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 14)
                        else
                          Text(
                            file.sizeString,
                            style: PulseTypography.monoLabel.copyWith(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail() {
    if (file.isVideo) {
      return VideoThumbnailWidget(
        videoPath: file.path,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (file.albumArtPath != null && file.albumArtPath!.isNotEmpty) {
      return Image.file(
        File(file.albumArtPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(48),
      );
    }
    return _buildPlaceholder(48);
  }

  Widget _buildPlaceholder(double iconSize) {
    return Container(
      color: PulseColors.surface,
      child: Icon(
        Icons.music_note_rounded,
        size: iconSize,
        color: PulseColors.accentPrimary,
      ),
    );
  }

  String _getFolderName(String path) {
    try {
      final separator = path.contains('/') ? '/' : '\\';
      final parts = path.split(separator);
      if (parts.length > 1) {
        return parts[parts.length - 2];
      }
      return 'Videos';
    } catch (_) {
      return 'Videos';
    }
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }
}

// ─── Shared checkbox widget ───────────────────────────────────────────────────
class _SelectionCheckbox extends StatelessWidget {
  final bool selected;
  const _SelectionCheckbox({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? PulseColors.accentSecondary : Colors.black45,
        border: Border.all(
          color: selected ? PulseColors.accentSecondary : Colors.white60,
          width: 1.8,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
          : null,
    );
  }
}

// ─── SpinningThumbnail (updated to support dynamic isSpinning) ─────────
class SpinningThumbnail extends StatefulWidget {
  final Widget child;
  final bool isSpinning;
  const SpinningThumbnail({Key? key, required this.child, this.isSpinning = false}) : super(key: key);

  @override
  State<SpinningThumbnail> createState() => _SpinningThumbnailState();
}

class _SpinningThumbnailState extends State<SpinningThumbnail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    if (widget.isSpinning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SpinningThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpinning != oldWidget.isSpinning) {
      if (widget.isSpinning) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSpinning) {
      return widget.child;
    }

    return RotationTransition(
      turns: _controller,
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            widget.child,
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF12121A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EqualizerBarsIndicator (animated equalizer for currently-playing audio) ────
class EqualizerBarsIndicator extends StatefulWidget {
  final Color color;
  final bool isAnimating;

  const EqualizerBarsIndicator({
    Key? key,
    required this.color,
    this.isAnimating = true,
  }) : super(key: key);

  @override
  State<EqualizerBarsIndicator> createState() => _EqualizerBarsIndicatorState();
}

class _EqualizerBarsIndicatorState extends State<EqualizerBarsIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _barAnims;

  static const _barCount = 3;
  static const _phases = [0.0, 0.35, 0.65];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _barAnims = List.generate(_barCount, (i) {
      final phase = _phases[i];
      return TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.3, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.3).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 50,
        ),
      ]).animate(CurvedAnimation(
        parent: _controller,
        curve: Interval(phase, (phase + 0.65).clamp(0.0, 1.0)),
      ));
    });
    if (widget.isAnimating) _controller.repeat();
  }

  @override
  void didUpdateWidget(EqualizerBarsIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 16,
          height: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_barCount, (i) {
              final heightFactor = widget.isAnimating ? _barAnims[i].value : 0.5;
              return Container(
                width: 3,
                height: 14 * heightFactor,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(1.5),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ─── PulsingIndicatorLight (glowing dot for active video items) ──────────
class _PulsingIndicatorLight extends StatefulWidget {
  final Color color;
  const _PulsingIndicatorLight({Key? key, required this.color}) : super(key: key);

  @override
  State<_PulsingIndicatorLight> createState() => _PulsingIndicatorLightState();
}

class _PulsingIndicatorLightState extends State<_PulsingIndicatorLight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _animation.value),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.6 * _animation.value),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
