import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

/// Ultra-smooth, hardware-accelerated interactive Play/Pause button with
/// tactile spring physics, expanding shockwave burst, morphing animated icon,
/// and reactive neon breathing halo.
///
/// Designed with [RepaintBoundary] to ensure zero frame-drops and zero lag.
class PulseInteractivePlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final double size;
  final Color? color;
  final Color? iconColor;
  final Color? glowColor;
  final bool showGlow;
  final Gradient? gradient;

  const PulseInteractivePlayButton({
    Key? key,
    required this.isPlaying,
    required this.onTap,
    this.size = 56,
    this.color,
    this.iconColor,
    this.glowColor,
    this.showGlow = true,
    this.gradient,
  }) : super(key: key);

  @override
  State<PulseInteractivePlayButton> createState() => _PulseInteractivePlayButtonState();
}

class _PulseInteractivePlayButtonState extends State<PulseInteractivePlayButton>
    with TickerProviderStateMixin {
  late final AnimationController _springController;
  late final Animation<double> _scaleAnimation;

  late final AnimationController _morphController;
  late final Animation<double> _morphAnimation;

  late final AnimationController _shockwaveController;
  late final Animation<double> _shockwaveScale;
  late final Animation<double> _shockwaveOpacity;

  late final AnimationController _breathingController;
  late final Animation<double> _breathingGlow;

  @override
  void initState() {
    super.initState();

    // 1. Spring compression / rebound animation (180ms snappy tactile feel)
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.85).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.08).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_springController);

    // 2. Play <-> Pause morphing icon animation
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: widget.isPlaying ? 1.0 : 0.0,
    );
    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeInOutBack,
    );

    // 3. Shockwave burst ring expanding on tap
    _shockwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shockwaveScale = Tween<double>(begin: 0.9, end: 1.75).animate(
      CurvedAnimation(parent: _shockwaveController, curve: Curves.easeOutQuad),
    );
    _shockwaveOpacity = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _shockwaveController, curve: Curves.easeOutQuad),
    );

    // 4. Subtle breathing glow when active
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _breathingGlow = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    if (widget.isPlaying) {
      _breathingController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PulseInteractivePlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _morphController.forward();
        _breathingController.repeat(reverse: true);
      } else {
        _morphController.reverse();
        _breathingController.stop();
        _breathingController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _springController.dispose();
    _morphController.dispose();
    _shockwaveController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  void _handleTap() {
    // 1. Haptic click feedback
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    // 2. Fire spring recoil & shockwave burst concurrently
    _springController.forward(from: 0.0);
    _shockwaveController.forward(from: 0.0);

    // 3. Trigger playback action
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? PulseColors.accentPrimary;
    final activeGlowColor = widget.glowColor ?? activeColor;
    final iconColor = widget.iconColor ?? Colors.black;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size * 1.5,
        height: widget.size * 1.5,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Shockwave Burst Ring
            AnimatedBuilder(
              animation: _shockwaveController,
              builder: (context, _) {
                if (_shockwaveController.isDismissed) return const SizedBox.shrink();
                return Opacity(
                  opacity: _shockwaveOpacity.value,
                  child: Transform.scale(
                    scale: _shockwaveScale.value,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: activeGlowColor,
                          width: 2.2,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Breathing Ambient Halo Glow
            if (widget.showGlow)
              AnimatedBuilder(
                animation: _breathingGlow,
                builder: (context, _) {
                  final glowOpacity = widget.isPlaying ? _breathingGlow.value : 0.25;
                  return Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: activeGlowColor.withValues(alpha: glowOpacity),
                          blurRadius: widget.isPlaying ? 20 : 10,
                          spreadRadius: widget.isPlaying ? 4 : 1,
                        ),
                      ],
                    ),
                  );
                },
              ),

            // Main Tactile Button
            GestureDetector(
              onTap: _handleTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.gradient ??
                        LinearGradient(
                          colors: [
                            activeColor,
                            activeColor.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedIcon(
                      icon: AnimatedIcons.play_pause,
                      progress: _morphAnimation,
                      color: iconColor,
                      size: widget.size * 0.52,
                    ),
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
