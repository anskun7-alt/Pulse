import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart' hide RepeatMode;
import 'dart:math' as math;
import '../models/media_file.dart';
import '../services/playback_service.dart';
import '../services/color_service.dart';
import '../services/playlist_service.dart';
import '../widgets/visualizer_widget.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/equalizer_screen.dart';
import '../widgets/queue_sheet.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'package:hive/hive.dart';

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({Key? key}) : super(key: key);

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> with TickerProviderStateMixin {
  final _playback = PlaybackService.instance;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  
  // Card Flip animation parameters
  bool _showLyrics = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  String _visualizerStyle = 'Bars';
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    
    // Slow rotating album art
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    // Glowing CD pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 3D card flip animation
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    // Watch play status
    _playback.isPlaying.addListener(_handlePlayStatus);
    _handlePlayStatus();

    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox('settings_box');
    setState(() {
      _visualizerStyle = box.get('visualizer_style', defaultValue: 'Bars') as String;
    });
  }

  void _handlePlayStatus() {
    if (!mounted) return;
    if (_playback.isPlaying.value) {
      _rotationController.repeat();
      _pulseController.repeat(reverse: true);
    } else {
      _rotationController.stop();
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _playback.isPlaying.removeListener(_handlePlayStatus);
    _rotationController.dispose();
    _pulseController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    setState(() {
      _showLyrics = !_showLyrics;
      if (_showLyrics) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  void _showSleepTimerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF12121E).withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: const Color(0xFF1E1E30).withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    "Sleep Timer",
                    style: PulseTypography.displayMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text("15 minutes", style: PulseTypography.bodyLarge),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white60),
                    onTap: () {
                      _playback.setSleepTimer(15);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: Text("30 minutes", style: PulseTypography.bodyLarge),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white60),
                    onTap: () {
                      _playback.setSleepTimer(30);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: Text("45 minutes", style: PulseTypography.bodyLarge),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white60),
                    onTap: () {
                      _playback.setSleepTimer(45);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: Text("60 minutes", style: PulseTypography.bodyLarge),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white60),
                    onTap: () {
                      _playback.setSleepTimer(60);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: Text("Turn Off Timer", style: PulseTypography.bodyLarge.copyWith(color: PulseColors.danger)),
                    trailing: Icon(Icons.power_settings_new_rounded, color: PulseColors.danger),
                    onTap: () {
                      _playback.setSleepTimer(0);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: ValueListenableBuilder<MediaFile?>(
        valueListenable: _playback.currentTrack,
        builder: (context, track, child) {
          if (track == null) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            );
          }

          return ValueListenableBuilder<Color>(
            valueListenable: ColorService.instance.activeAccent,
            builder: (context, accentColor, child) {
              return Scaffold(
                backgroundColor: PulseColors.background,
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Dynamic color mesh background
                    Positioned.fill(
                      child: _AnimatedMeshBackground(baseColor: accentColor),
                    ),

                    // Content Area
                    SafeArea(
                      child: Column(
                        children: [
                          // Top Bar Actions
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _AnimatedTapScale(
                                  onTap: () => Navigator.pop(context),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
                                  ),
                                ),
                                Text(
                                  "Now Playing",
                                  style: PulseTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                ),
                                _AnimatedTapScale(
                                  onTap: () {},
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(Icons.more_vert_rounded, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // Album Art card / Synced Lyrics with Card Flip transition
                          GestureDetector(
                            onTap: _toggleFlip,
                            child: AnimatedBuilder(
                              animation: _flipAnimation,
                              builder: (context, child) {
                                final transformVal = _flipAnimation.value * math.pi;
                                final isBack = transformVal >= math.pi / 2;

                                return Transform(
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001) // perspective
                                    ..rotateY(transformVal),
                                  alignment: Alignment.center,
                                  child: isBack
                                      // Render back of card -> Lyrics View
                                      ? Transform(
                                          transform: Matrix4.identity()..rotateY(math.pi),
                                          alignment: Alignment.center,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(24),
                                            child: Container(
                                              width: 300,
                                              height: 300,
                                              color: Colors.black.withValues(alpha: 0.5),
                                              child: LyricsView(file: track),
                                            ),
                                          ),
                                        )
                                      // Render front of card -> Cover image with dynamic pulsing glow
                                      : Center(
                                          child: AnimatedBuilder(
                                            animation: Listenable.merge([_rotationController, _pulseController]),
                                            builder: (context, child) {
                                              final pVal = _pulseController.value;
                                              final glowRadius = 20 + pVal * 20;
                                              final spread = -3 + pVal * 5;
                                              return Transform.rotate(
                                                angle: _rotationController.value * 2 * math.pi,
                                                child: Container(
                                                  width: 260,
                                                  height: 260,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: accentColor.withValues(alpha: 0.5 + pVal * 0.25),
                                                        blurRadius: glowRadius,
                                                        spreadRadius: spread,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                      BoxShadow(
                                                        color: accentColor.withValues(alpha: 0.25),
                                                        blurRadius: glowRadius * 1.5,
                                                        spreadRadius: spread - 1.5,
                                                        offset: const Offset(0, 8),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipOval(
                                                    child: _AudioArtWidget(
                                                      artPath: track.albumArtPath,
                                                      size: 260,
                                                      fallbackIconSize: 80,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Canvas Visualizer
                          VisualizerWidget(style: _visualizerStyle),

                          const Spacer(),

                          // Song Details Section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: PulseTypography.displayLarge,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        track.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: PulseTypography.bodyLarge.copyWith(color: PulseColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                ValueListenableBuilder<List<String>>(
                                  valueListenable: PlaylistService.instance.favorites,
                                  builder: (context, favs, child) {
                                    final isFav = favs.contains(track.path);
                                    return _AnimatedTapScale(
                                      onTap: () async {
                                        final box = await Hive.openBox('media_files_box');
                                        await PlaylistService.instance.toggleFavorite(track, box);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Icon(
                                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                          color: isFav ? Colors.redAccent : Colors.white,
                                          size: 28,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Timeline Seek Track Bar progress
                          Padding(
                            padding: const EdgeInsets.only(left: 32, right: 32, top: 20),
                            child: Column(
                              children: [
                                ValueListenableBuilder<Duration>(
                                  valueListenable: _playback.position,
                                  builder: (context, pos, child) {
                                    return ValueListenableBuilder<Duration>(
                                      valueListenable: _playback.duration,
                                      builder: (context, dur, child) {
                                        final displayDur = dur == Duration.zero ? track.duration : dur;
                                        final totalMs = displayDur.inMilliseconds.toDouble();
                                        final currentMs = pos.inMilliseconds.toDouble();
                                        return Column(
                                          children: [
                                            SliderTheme(
                                              data: SliderTheme.of(context).copyWith(
                                                activeTrackColor: accentColor,
                                                inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                                                valueIndicatorColor: accentColor,
                                                thumbColor: Colors.white,
                                                trackHeight: _isDragging ? 6.0 : 4.0,
                                                thumbShape: RoundSliderThumbShape(
                                                  enabledThumbRadius: _isDragging ? 10.0 : 6.0,
                                                  elevation: _isDragging ? 8.0 : 2.0,
                                                ),
                                                overlayColor: accentColor.withValues(alpha: 0.2),
                                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
                                              ),
                                              child: Slider(
                                                value: currentMs.clamp(0.0, totalMs),
                                                min: 0.0,
                                                max: totalMs > 0.0 ? totalMs : 1.0,
                                                onChangeStart: (_) {
                                                  setState(() {
                                                    _isDragging = true;
                                                  });
                                                },
                                                onChangeEnd: (_) {
                                                  setState(() {
                                                    _isDragging = false;
                                                  });
                                                },
                                                onChanged: (val) {
                                                  _playback.seek(Duration(milliseconds: val.round()));
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(_formatDuration(pos), style: PulseTypography.monoLabel.copyWith(color: Colors.white70)),
                                                Text(_formatDuration(displayDur), style: PulseTypography.monoLabel.copyWith(color: Colors.white70)),
                                              ],
                                            )
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Controls play icons row
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── Secondary row: shuffle + repeat ─────────────
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Shuffle
                                    ValueListenableBuilder<bool>(
                                      valueListenable: _playback.isShuffle,
                                      builder: (context, shuf, child) {
                                        return _AnimatedTapScale(
                                          onTap: () => _playback.toggleShuffle(),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Icon(
                                              Icons.shuffle_rounded,
                                              color: shuf ? accentColor : Colors.white60,
                                              size: 22,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 48),
                                    // Repeat
                                    ValueListenableBuilder<RepeatMode>(
                                      valueListenable: _playback.repeatMode,
                                      builder: (context, mode, child) {
                                        IconData icon = Icons.repeat_rounded;
                                        Color color = Colors.white60;
                                        if (mode == RepeatMode.all) {
                                          color = accentColor;
                                        } else if (mode == RepeatMode.one) {
                                          icon = Icons.repeat_one_rounded;
                                          color = accentColor;
                                        }
                                        return _AnimatedTapScale(
                                          onTap: () => _playback.toggleRepeat(),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Icon(
                                              icon,
                                              color: color,
                                              size: 22,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // ── Primary row: skip-5 | prev | play | next | skip+5 ──
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Skip backward 5s
                                    _AnimatedTapScale(
                                      onTap: () => _playback.seekRelative(const Duration(seconds: -5)),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.replay_5_rounded, color: Colors.white, size: 28),
                                      ),
                                    ),
                                    // Previous track
                                    _AnimatedTapScale(
                                      onTap: () => _playback.previous(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 34),
                                      ),
                                    ),
                                    // Play / Pause — large centred button
                                    ValueListenableBuilder<bool>(
                                      valueListenable: _playback.isPlaying,
                                      builder: (context, playing, child) {
                                        return _AnimatedTapScale(
                                          onTap: () => _playback.togglePlay(),
                                          child: Container(
                                            width: 68,
                                            height: 68,
                                            decoration: BoxDecoration(
                                              color: accentColor,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: accentColor.withValues(alpha: 0.4),
                                                  blurRadius: 16,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                              color: Colors.black,
                                              size: 40,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // Next track
                                    _AnimatedTapScale(
                                      onTap: () => _playback.next(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.skip_next_rounded, color: Colors.white, size: 34),
                                      ),
                                    ),
                                    // Skip forward 5s
                                    _AnimatedTapScale(
                                      onTap: () => _playback.seekRelative(const Duration(seconds: 5)),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.forward_5_rounded, color: Colors.white, size: 28),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Sleep, Equalizer, Speed footer actions
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      // Sleep Timer button
                                      ValueListenableBuilder<int>(
                                        valueListenable: _playback.sleepSecondsRemaining,
                                        builder: (context, secs, child) {
                                          final active = secs > 0;
                                          final mins = (secs / 60).ceil();
                                          return _AnimatedTapScale(
                                            onTap: _showSleepTimerSheet,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.bedtime_outlined, color: active ? accentColor : Colors.white70),
                                                const SizedBox(width: 8),
                                                Text(
                                                  active ? "${mins}m" : "Sleep",
                                                  style: TextStyle(color: active ? accentColor : Colors.white70, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      // Divider separator
                                      Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.15)),
                                      // EQ button
                                      _AnimatedTapScale(
                                        onTap: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => const EqualizerScreen()));
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.graphic_eq_rounded, color: Colors.white70),
                                            const SizedBox(width: 8),
                                            const Text("EQ", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      // Divider separator
                                      Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.15)),
                                      // Speed controls selector
                                      ValueListenableBuilder<double>(
                                        valueListenable: _playback.playbackSpeed,
                                        builder: (context, spd, child) {
                                          return _AnimatedTapScale(
                                            onTap: () {
                                              // Cycle speed
                                              final nextIdx = (_playback.speeds.indexOf(spd) + 1) % _playback.speeds.length;
                                              _playback.setSpeed(_playback.speeds[nextIdx]);
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.slow_motion_video_rounded, color: Colors.white70),
                                                const SizedBox(width: 8),
                                                Text("${spd}x", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      // Divider separator
                                      Container(width: 1, height: 24, color: Colors.white.withValues(alpha: 0.15)),
                                      // Queue button
                                      _AnimatedTapScale(
                                        onTap: () => QueueBottomSheet.show(context),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.queue_music_rounded, color: Colors.white70),
                                            SizedBox(width: 8),
                                            Text("Queue", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
        },
      ),
    );
  }
}

class _AudioArtWidget extends StatelessWidget {
  final String? artPath;
  final double size;
  final double fallbackIconSize;

  const _AudioArtWidget({
    required this.artPath,
    required this.size,
    required this.fallbackIconSize,
  });

  @override
  Widget build(BuildContext context) {
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

class _AnimatedMeshBackground extends StatefulWidget {
  final Color baseColor;

  const _AnimatedMeshBackground({
    Key? key,
    required this.baseColor,
  }) : super(key: key);

  @override
  State<_AnimatedMeshBackground> createState() => _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<_AnimatedMeshBackground> with TickerProviderStateMixin {
  late AnimationController _anim1;
  late AnimationController _anim2;

  late Animation<Alignment> _align1;
  late Animation<Alignment> _align2;
  late Animation<double> _scale1;
  late Animation<double> _scale2;

  @override
  void initState() {
    super.initState();
    _anim1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _anim2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);

    _align1 = Tween<Alignment>(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).animate(CurvedAnimation(parent: _anim1, curve: Curves.easeInOut));

    _align2 = Tween<Alignment>(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
    ).animate(CurvedAnimation(parent: _anim2, curve: Curves.easeInOut));

    _scale1 = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _anim1, curve: Curves.easeInOut),
    );

    _scale2 = Tween<double>(begin: 1.2, end: 0.7).animate(
      CurvedAnimation(parent: _anim2, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _anim1.dispose();
    _anim2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.baseColor;
    final secondary = HSLColor.fromColor(primary).withHue((HSLColor.fromColor(primary).hue + 60) % 360).toColor();
    final tertiary = HSLColor.fromColor(primary).withHue((HSLColor.fromColor(primary).hue + 180) % 360).toColor();

    return Stack(
      children: [
        Container(
          color: const Color(0xFF040408),
        ),
        AnimatedBuilder(
          animation: _anim1,
          builder: (context, child) {
            return Align(
              alignment: _align1.value,
              child: Transform.scale(
                scale: _scale1.value,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        primary.withValues(alpha: 0.35),
                        primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _anim2,
          builder: (context, child) {
            return Align(
              alignment: _align2.value,
              child: Transform.scale(
                scale: _scale2.value,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        secondary.withValues(alpha: 0.3),
                        secondary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Align(
          alignment: const Alignment(0, 0.8),
          child: Container(
            width: 450,
            height: 450,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  tertiary.withValues(alpha: 0.15),
                  tertiary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
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
