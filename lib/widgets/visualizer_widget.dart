import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/playback_service.dart';
import '../services/color_service.dart';
import '../theme/colors.dart';

class VisualizerWidget extends StatefulWidget {
  final String style; // 'Bars' | 'Wave' | 'Circle' | 'Off'

  const VisualizerWidget({
    Key? key,
    required this.style,
  }) : super(key: key);

  @override
  State<VisualizerWidget> createState() => _VisualizerWidgetState();
}

class _VisualizerWidgetState extends State<VisualizerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final math.Random _random = math.Random();
  late List<double> _barHeights;

  @override
  void initState() {
    super.initState();
    _barHeights = List.generate(24, (index) => 0.1 + _random.nextDouble() * 0.8);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Pause/Play visualizer based on player state
    PlaybackService.instance.isPlaying.addListener(_handlePlayState);
    _handlePlayState();
  }

  void _handlePlayState() {
    if (PlaybackService.instance.isPlaying.value) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    PlaybackService.instance.isPlaying.removeListener(_handlePlayState);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.style == 'Off') return const SizedBox(height: 60);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Dynamic color based on current active accent
        final color = ColorService.instance.activeAccent.value;

        return SizedBox(
          height: 80,
          width: double.infinity,
          child: CustomPaint(
            painter: _VisualizerPainter(
              style: widget.style,
              animationValue: _controller.value,
              barHeights: _barHeights,
              color: color,
            ),
          ),
        );
      },
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final String style;
  final double animationValue;
  final List<double> barHeights;
  final Color color;

  _VisualizerPainter({
    required this.style,
    required this.animationValue,
    required this.barHeights,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (style == 'Bars') {
      _paintBars(canvas, size, paint);
    } else if (style == 'Wave') {
      _paintWave(canvas, size);
    } else if (style == 'Circle') {
      _paintCircle(canvas, size);
    }
  }

  void _paintBars(Canvas canvas, Size size, Paint paint) {
    final barWidth = size.width / (barHeights.length * 1.5);
    final gap = barWidth * 0.5;
    
    for (int i = 0; i < barHeights.length; i++) {
      // Calculate animated height using sine waves combined with random seed heights
      final wave = math.sin((animationValue * 2 * math.pi) + (i * 0.5));
      final h = size.height * barHeights[i] * (0.3 + 0.7 * wave.abs());
      
      final x = i * (barWidth + gap) + gap;
      final y = size.height - h;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        Radius.circular(barWidth / 2),
      );

      // Create glowing shader
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(rect, glowPaint);
      
      canvas.drawRRect(rect, paint);
    }
  }

  void _paintWave(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final paint2 = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path1 = Path();
    final path2 = Path();

    path1.moveTo(0, size.height / 2);
    path2.moveTo(0, size.height / 2);

    for (double x = 0; x <= size.width; x += 4) {
      final rad1 = (x / size.width * 3 * math.pi) + (animationValue * 2 * math.pi);
      final rad2 = (x / size.width * 5 * math.pi) - (animationValue * 2 * math.pi);
      
      final y1 = size.height / 2 + math.sin(rad1) * 20 * math.cos(rad1 * 0.5);
      final y2 = size.height / 2 + math.sin(rad2) * 12 * math.sin(rad2 * 0.3);

      path1.lineTo(x, y1);
      path2.lineTo(x, y2);
    }

    // Add glowing filter to the main path
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path1, glowPaint);

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  void _paintCircle(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) / 2.2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    final int points = 60;

    for (int i = 0; i <= points; i++) {
      final angle = (i / points) * 2 * math.pi;
      final wave = math.sin((angle * 8) + (animationValue * 2 * math.pi));
      final r = baseRadius + wave * 6;

      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(path, glowPaint);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
