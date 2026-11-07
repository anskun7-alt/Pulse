import 'package:flutter/material.dart';

/// Smooth auto-scrolling marquee for song/video titles that overflow their container.
class PulseMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseDuration;
  final double velocity; // Pixels per second

  const PulseMarqueeText({
    Key? key,
    required this.text,
    this.style,
    this.pauseDuration = const Duration(seconds: 2),
    this.velocity = 28.0,
  }) : super(key: key);

  @override
  State<PulseMarqueeText> createState() => _PulseMarqueeTextState();
}

class _PulseMarqueeTextState extends State<PulseMarqueeText> {
  late final ScrollController _scrollController;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loopScroll());
  }

  @override
  void didUpdateWidget(covariant PulseMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _loopScroll());
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  bool _isScrolling = false;

  Future<void> _loopScroll() async {
    if (_isDisposed || !mounted || !_scrollController.hasClients || _isScrolling) return;
    _isScrolling = true;

    try {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      while (mounted && !_isDisposed && _scrollController.hasClients) {
        await Future.delayed(widget.pauseDuration);
        if (!mounted || _isDisposed || !_scrollController.hasClients) break;

        final currentMax = _scrollController.position.maxScrollExtent;
        if (currentMax <= 0) break;

        final durationMs = ((currentMax / widget.velocity) * 1000).toInt().clamp(800, 15000);

        await _scrollController.animateTo(
          currentMax,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.linear,
        );

        await Future.delayed(widget.pauseDuration);
        if (!mounted || _isDisposed || !_scrollController.hasClients) break;

        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (_) {
    } finally {
      _isScrolling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}
