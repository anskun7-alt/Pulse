import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';

/// Spring-physics tactile bounce widget for interactive buttons and media cards.
class BouncingTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final Duration duration;

  const BouncingTap({
    Key? key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.94,
    this.duration = const Duration(milliseconds: 120),
  }) : super(key: key);

  @override
  State<BouncingTap> createState() => _BouncingTapState();
}

class _BouncingTapState extends State<BouncingTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _controller.reverse();
    });
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Floating glassmorphism action pill with glowing neon border on hover/press.
class PulseGlassPill extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const PulseGlassPill({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primary = PulseColors.accentPrimary;

    return BouncingTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primary.withValues(alpha: 0.22) : PulseColors.surfaceHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? primary : Colors.white12,
            width: 1.2,
          ),
          boxShadow: isActive ? PulseColors.glowShadow(primary) : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : PulseColors.textSecondary,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic ambient backlight halo card wrapper that casts a soft radiant glow.
class PulseAmbientGlow extends StatelessWidget {
  final Widget child;
  final Color? glowColor;
  final double blurRadius;
  final double spreadRadius;
  final BorderRadius? borderRadius;

  const PulseAmbientGlow({
    Key? key,
    required this.child,
    this.glowColor,
    this.blurRadius = 32,
    this.spreadRadius = 2,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = glowColor ?? PulseColors.accentPrimary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: blurRadius,
            spreadRadius: spreadRadius,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Live 4-bar animated equalizer badge that bounces smoothly during playback.
class PulseAnimatedEqualizer extends StatefulWidget {
  final Color? color;
  final double size;
  final bool isPlaying;

  const PulseAnimatedEqualizer({
    Key? key,
    this.color,
    this.size = 18,
    this.isPlaying = true,
  }) : super(key: key);

  @override
  State<PulseAnimatedEqualizer> createState() => _PulseAnimatedEqualizerState();
}

class _PulseAnimatedEqualizerState extends State<PulseAnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PulseAnimatedEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.color ?? PulseColors.accentPrimary;
    final barWidth = widget.size * 0.18;
    final spacing = widget.size * 0.08;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;

        // Dynamic staggered heights for 4 equalizer bars
        final h1 = widget.isPlaying ? (0.35 + 0.60 * ((math.sin(t) + 1) / 2)) : 0.25;
        final h2 = widget.isPlaying ? (0.25 + 0.70 * ((math.sin(t + 1.2) + 1) / 2)) : 0.40;
        final h3 = widget.isPlaying ? (0.40 + 0.55 * ((math.sin(t + 2.5) + 1) / 2)) : 0.30;
        final h4 = widget.isPlaying ? (0.30 + 0.65 * ((math.sin(t + 3.8) + 1) / 2)) : 0.20;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(barWidth, widget.size * h1, barColor),
              SizedBox(width: spacing),
              _buildBar(barWidth, widget.size * h2, barColor),
              SizedBox(width: spacing),
              _buildBar(barWidth, widget.size * h3, barColor),
              SizedBox(width: spacing),
              _buildBar(barWidth, widget.size * h4, barColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double width, double height, Color color) {
    return Container(
      width: width,
      height: height.clamp(2.0, widget.size),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width / 2),
      ),
    );
  }
}


/// Snappy touch-and-hold tactile detector with 220ms responsiveness (instead of Flutter's 500ms default)
/// and subtle spring scale compression for instant tactile feedback.
class PulseQuickHold extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onHold;
  final Duration holdDuration;
  final double scaleFactor;

  const PulseQuickHold({
    Key? key,
    required this.child,
    required this.onTap,
    this.onHold,
    this.holdDuration = const Duration(milliseconds: 220),
    this.scaleFactor = 0.965,
  }) : super(key: key);

  @override
  State<PulseQuickHold> createState() => _PulseQuickHoldState();
}

class _PulseQuickHoldState extends State<PulseQuickHold> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Timer? _holdTimer;
  Offset? _downPosition;
  bool _didTriggerHold = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _downPosition = event.position;
    _didTriggerHold = false;
    _controller.forward();

    if (widget.onHold != null) {
      _holdTimer?.cancel();
      _holdTimer = Timer(widget.holdDuration, () {
        if (!mounted) return;
        _didTriggerHold = true;
        HapticFeedback.mediumImpact();
        widget.onHold!();
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_downPosition != null) {
      final dist = (event.position - _downPosition!).distance;
      if (dist > 14.0) {
        // Finger is scrolling -> cancel hold timer & restore card scale
        _holdTimer?.cancel();
        _holdTimer = null;
        if (!_didTriggerHold && _controller.value > 0) {
          _controller.reverse();
        }
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _controller.reverse();
    if (_holdTimer != null && !_didTriggerHold) {
      _holdTimer?.cancel();
      _holdTimer = null;
      HapticFeedback.selectionClick();
      widget.onTap();
    }
    _didTriggerHold = false;
    _downPosition = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _holdTimer?.cancel();
    _holdTimer = null;
    _controller.reverse();
    _didTriggerHold = false;
    _downPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
