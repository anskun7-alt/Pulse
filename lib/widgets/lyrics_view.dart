import 'package:flutter/material.dart';
import '../models/media_file.dart';
import '../services/lyrics_service.dart';
import '../services/playback_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class LyricsView extends StatefulWidget {
  final MediaFile file;

  const LyricsView({
    Key? key,
    required this.file,
  }) : super(key: key);

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final _lyricsService = LyricsService.instance;
  final _playbackService = PlaybackService.instance;
  final _scrollController = ScrollController();

  List<LyricLine>? _syncedLines;
  String? _plainLyrics;
  bool _isLoading = true;
  int _currentIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
    _playbackService.position.addListener(_onPositionChange);
  }

  @override
  void dispose() {
    _playbackService.position.removeListener(_onPositionChange);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    setState(() {
      _isLoading = true;
      _syncedLines = null;
      _plainLyrics = null;
    });

    final data = await _lyricsService.fetchLyrics(
      widget.file.title,
      widget.file.artist,
      duration: widget.file.duration,
    );

    if (data != null) {
      if (data['synced'] != null) {
        _syncedLines = _lyricsService.parseSyncedLyrics(data['synced']);
      } else {
        _plainLyrics = data['plain'];
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onPositionChange() {
    if (_syncedLines == null || _syncedLines!.isEmpty || !mounted) return;
    
    final currentPos = _playbackService.position.value;
    int index = -1;
    
    for (int i = 0; i < _syncedLines!.length; i++) {
      if (currentPos >= _syncedLines![i].timestamp) {
        index = i;
      } else {
        break;
      }
    }

    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
      _scrollToIndex(index);
    }
  }

  void _scrollToIndex(int index) {
    if (index < 0 || !_scrollController.hasClients) return;
    
    // Estimate line height and scroll smoothly to center active line
    final offset = index * 52.0 - MediaQuery.of(context).size.height * 0.25;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: PulseColors.accentPrimary),
      );
    }

    if (_syncedLines == null && _plainLyrics == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off_rounded, size: 64, color: PulseColors.textSecondary),
            const SizedBox(height: 16),
            Text("No lyrics found.", style: PulseTypography.bodyLarge),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadLyrics,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Try again"),
              style: ElevatedButton.styleFrom(
                backgroundColor: PulseColors.accentPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      );
    }

    // Standard static plain lyrics layout
    if (_plainLyrics != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Text(
          _plainLyrics!,
          textAlign: TextAlign.center,
          style: PulseTypography.bodyLarge.copyWith(
            fontSize: 18,
            height: 1.8,
          ),
        ),
      );
    }

    // Synced scrolling lyrics layout
    return ListView.builder(
      controller: _scrollController,
      itemCount: _syncedLines!.length,
      padding: const EdgeInsets.symmetric(vertical: 200, horizontal: 24),
      itemBuilder: (context, index) {
        final line = _syncedLines![index];
        final isActive = index == _currentIndex;
        final isPast = index < _currentIndex;

        // Apply progressive fading transitions
        double opacity = 0.35;
        if (isActive) {
          opacity = 1.0;
        } else if (isPast) {
          opacity = 0.5 - (0.05 * (_currentIndex - index)).clamp(0.0, 0.3);
        } else {
          opacity = 0.6 - (0.05 * (index - _currentIndex)).clamp(0.0, 0.4);
        }

        return GestureDetector(
          onTap: () {
            _playbackService.seek(line.timestamp);
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: isActive
                  ? PulseTypography.displayMedium.copyWith(color: Colors.white, fontSize: 24)
                  : PulseTypography.bodyLarge.copyWith(
                      color: Colors.white.withValues(alpha: opacity),
                      fontSize: 18,
                    ),
              textAlign: TextAlign.center,
              child: Text(line.text),
            ),
          ),
        );
      },
    );
  }
}
