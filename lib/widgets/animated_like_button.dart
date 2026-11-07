import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../models/media_file.dart';
import '../services/playlist_service.dart';
import '../theme/icons.dart';

class AnimatedLikeButton extends StatefulWidget {
  final MediaFile track;
  final double size;
  final EdgeInsetsGeometry padding;
  final ValueChanged<bool>? onFavoriteChanged;

  const AnimatedLikeButton({
    Key? key,
    required this.track,
    this.size = 28.0,
    this.padding = const EdgeInsets.all(8.0),
    this.onFavoriteChanged,
  }) : super(key: key);

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _burstAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    _burstAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap(bool currentIsFav) async {
    HapticFeedback.mediumImpact();
    if (!currentIsFav) {
      _controller.forward(from: 0.0);
    } else {
      _controller.reset();
    }

    try {
      final box = await Hive.openBox('media_files_box');
      await PlaylistService.instance.toggleFavorite(widget.track, box);
      final newFavState = !currentIsFav;
      widget.onFavoriteChanged?.call(newFavState);
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: PlaylistService.instance.favorites,
      builder: (context, favs, _) {
        final trackNorm = widget.track.path.replaceAll('\\', '/').toLowerCase();
        final isFav = favs.any((p) => p.replaceAll('\\', '/').toLowerCase() == trackNorm);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleTap(isFav),
          child: Padding(
            padding: widget.padding,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glowing particle burst ring when favoriting
                    if (_controller.isAnimating && isFav)
                      Opacity(
                        opacity: (1.0 - _burstAnimation.value).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 1.0 + (_burstAnimation.value * 0.9),
                          child: Container(
                            width: widget.size * 1.5,
                            height: widget.size * 1.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFF2E63).withValues(alpha: 0.8),
                                width: 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF2E63).withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Heart icon with spring bounce scale
                    Transform.scale(
                      scale: _controller.isAnimating ? _scaleAnimation.value : 1.0,
                      child: isFav
                          ? ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFFFF3366), Color(0xFFFF6584)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: Icon(
                                PulseIcons.favoriteIcon,
                                size: widget.size,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              PulseIcons.favoriteBorderIcon,
                              size: widget.size,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
