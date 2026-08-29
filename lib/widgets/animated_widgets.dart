import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Glowing, theme-tinted loading animation that adapts to the active Pulse theme palette.
class PulseLoadingIndicator extends StatelessWidget {
  final double size;
  final String? message;

  const PulseLoadingIndicator({
    Key? key,
    this.size = 100,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primary = PulseColors.accentPrimary;
    final secondary = PulseColors.accentSecondary;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Ambient Neon Glow
              Container(
                width: size * 0.7,
                height: size * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: 0.35),
                      secondary.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.2, 1.2), duration: 1500.ms),

              // Theme-tinted Lottie Loader
              SizedBox(
                width: size,
                height: size,
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [primary, secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: Lottie.asset(
                    'assets/animation/loading.json',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return CircularProgressIndicator(
                        color: primary,
                        strokeWidth: 3,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              style: PulseTypography.bodyMedium.copyWith(
                color: PulseColors.textSecondary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
          ]
        ],
      ),
    );
  }
}

/// Glassmorphism celebratory achievement popup with animated confetti and neon accents.
class PulseCelebrationDialog extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onDismiss;

  const PulseCelebrationDialog({
    Key? key,
    required this.title,
    required this.description,
    this.onDismiss,
  }) : super(key: key);

  static void show(BuildContext context, {required String title, required String description}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => PulseCelebrationDialog(
        title: title,
        description: description,
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = PulseColors.accentPrimary;
    final secondary = PulseColors.accentSecondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: PulseColors.surface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: primary.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.25),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Trophy / Celebration Animation
                SizedBox(
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              primary.withValues(alpha: 0.4),
                              secondary.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Lottie.asset(
                        'assets/animation/party_celebration.json',
                        repeat: false,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => Icon(
                          Icons.celebration_rounded,
                          size: 70,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: PulseTypography.displayMedium.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: PulseTypography.bodyMedium.copyWith(
                    color: PulseColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: PulseColors.glowShadow(primary),
                  ),
                  child: ElevatedButton(
                    onPressed: onDismiss ?? () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'Awesome',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack);
  }
}

/// Rich empty state illustration with ambient floating neon glow.
class PulseEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const PulseEmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primary = PulseColors.accentPrimary;
    final secondary = PulseColors.accentSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing ambient glow ring
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primary.withValues(alpha: 0.35),
                        secondary.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.15, 1.15), duration: 2000.ms),

                // Icon capsule
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: PulseColors.surfaceHigh.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [primary, secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: Icon(icon, size: 44, color: Colors.white),
                  ),
                ),
              ],
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: PulseTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                letterSpacing: -0.2,
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: PulseTypography.bodyMedium.copyWith(
                color: PulseColors.textSecondary,
                height: 1.4,
              ),
            ).animate().fadeIn(delay: 200.ms),
            if (action != null) ...[
              const SizedBox(height: 26),
              action!.animate().fadeIn(delay: 300.ms).slideY(begin: 0.15, end: 0),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mini animated equalizer bars in Pulse neon colors for active tracks.
class PulseEqualizerBars extends StatefulWidget {
  final bool isPlaying;
  final double height;

  const PulseEqualizerBars({
    Key? key,
    required this.isPlaying,
    this.height = 16,
  }) : super(key: key);

  @override
  State<PulseEqualizerBars> createState() => _PulseEqualizerBarsState();
}

class _PulseEqualizerBarsState extends State<PulseEqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseEqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat(reverse: true);
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
        final val = _controller.value;
        final primary = PulseColors.accentPrimary;
        final secondary = PulseColors.accentSecondary;

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar((val * 0.8 + 0.2).clamp(0.2, 1.0), primary),
            const SizedBox(width: 2.5),
            _buildBar(((1.0 - val) * 0.9 + 0.1).clamp(0.2, 1.0), secondary),
            const SizedBox(width: 2.5),
            _buildBar((val * 0.95 + 0.15).clamp(0.2, 1.0), primary),
          ],
        );
      },
    );
  }

  Widget _buildBar(double factor, Color color) {
    return Container(
      width: 3.5,
      height: widget.height * factor,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 4,
          )
        ],
      ),
    );
  }
}
