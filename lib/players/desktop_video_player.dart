import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/media_file.dart';
import '../services/playback_service.dart';
import '../services/shortcuts_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'package:hive/hive.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/animated_like_button.dart';
import '../widgets/interactive_play_button.dart';

enum DesktopRepeatMode { off, all, one }

class DesktopVideoPlayerScreen extends StatefulWidget {
  final MediaFile file;
  final List<MediaFile>? playlist;
  final Duration? initialPosition;

  const DesktopVideoPlayerScreen({
    Key? key,
    required this.file,
    this.playlist,
    this.initialPosition,
  }) : super(key: key);

  @override
  State<DesktopVideoPlayerScreen> createState() => _DesktopVideoPlayerScreenState();
}

class _DesktopVideoPlayerScreenState extends State<DesktopVideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  late List<MediaFile> _playlist;
  late int _currentIndex;

  bool _isShuffle = false;
  List<int> _shuffledDeck = [];
  int _shuffledDeckPointer = -1;
  DesktopRepeatMode _repeatMode = DesktopRepeatMode.all; // Default to looping the playlist seamlessly!

  bool _showControls = true;
  Timer? _controlsTimer;

  bool _isLocked = false;
  bool _showLockIndicator = false;
  Timer? _lockIndicatorTimer;
  bool _showUnlockButton = false;
  Timer? _unlockButtonTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _volume = 100.0;
  double _speed = 1.0;
  int _rotation = 0; // 0, 90, 180, 270 degrees
  bool _isMuted = false;
  bool _isDragging = false;
  double _dragVal = 0.0;
  Offset? _lastDoubleTapPosition;
  bool _isFullscreen = false;

  bool _showResumePrompt = false;
  Duration? _savedResumePosition;
  Timer? _resumePromptTimer;

  String? _overlayText;
  IconData? _overlayIcon;
  Timer? _overlayTimer;
  final FocusNode _focusNode = FocusNode();
  bool _isPopping = false;

  void _showLockedFeedback() {
    HapticFeedback.lightImpact();
    setState(() {
      _showLockIndicator = true;
      _showUnlockButton = true;
    });
    _lockIndicatorTimer?.cancel();
    _lockIndicatorTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showLockIndicator = false);
    });
    _unlockButtonTimer?.cancel();
    _unlockButtonTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _showUnlockButton = false);
    });
  }

  void _unlockScreen() {
    HapticFeedback.mediumImpact();
    _lockIndicatorTimer?.cancel();
    _unlockButtonTimer?.cancel();
    setState(() {
      _isLocked = false;
      _showLockIndicator = false;
      _showUnlockButton = false;
      _showControls = true;
    });
    _startControlsTimer();
    _showOverlayHUD('Screen Unlocked', icon: Icons.lock_open_rounded);
  }

  void _toggleLock() {
    if (_isLocked) {
      _unlockScreen();
    } else {
      HapticFeedback.mediumImpact();
      _lockIndicatorTimer?.cancel();
      _unlockButtonTimer?.cancel();
      setState(() {
        _isLocked = true;
        _showControls = false;
        _showUnlockButton = false;
        _showLockIndicator = false;
      });
      _controlsTimer?.cancel();
      _showOverlayHUD('Screen Locked', icon: Icons.lock_rounded);
    }
  }

  // Stream subscriptions
  late final StreamSubscription _posSub;
  late final StreamSubscription _durSub;
  late final StreamSubscription _playingSub;
  late final StreamSubscription _completedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      try {
        final defaultFullscreen = Hive.box('settings_box').get('default_fullscreen', defaultValue: true) as bool;
        if (defaultFullscreen && mounted && !_isFullscreen) {
          _toggleFullscreen();
        }
      } catch (_) {}
    });
    _playlist = widget.playlist ?? [widget.file];
    _currentIndex = _playlist.indexWhere((f) => f.path == widget.file.path);
    if (_currentIndex == -1) _currentIndex = 0;

    _player = Player();
    _controller = VideoController(_player);

    int lastPosMs = 0;
    int lastSaveMs = 0;
    _posSub = _player.stream.position.listen((pos) {
      if (mounted && (pos.inMilliseconds - lastPosMs).abs() >= 250) {
        lastPosMs = pos.inMilliseconds;
        setState(() => _position = pos);

        if ((pos.inMilliseconds - lastSaveMs).abs() >= 2000) {
          lastSaveMs = pos.inMilliseconds;
          if (_currentIndex < _playlist.length) {
            final current = _playlist[_currentIndex];
            PlaybackService.instance.saveLastPlayed(current, pos);
            try {
              final box = Hive.box('settings_box');
              box.put('video_pos_${current.path}', pos.inMilliseconds);
            } catch (_) {}
          }
        }
      }
    });
    _durSub = _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _playingSub = _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    _completedSub = _player.stream.completed.listen((completed) {
      if (completed && mounted) _playNext(isAuto: true);
    });

    _openCurrentVideo(startAt: widget.initialPosition);
    _startControlsTimer();
  }

  void _saveCurrentProgress() {
    try {
      if (_currentIndex < _playlist.length && _position > Duration.zero) {
        final current = _playlist[_currentIndex];
        PlaybackService.instance.saveLastPlayed(current, _position);
        final box = Hive.box('settings_box');
        box.put('video_pos_${current.path}', _position.inMilliseconds);
      }
    } catch (_) {}
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _isFullscreen = !_isFullscreen);
    try {
      if (_isFullscreen) {
        await defaultEnterNativeFullscreen();
        _showOverlayHUD('Fullscreen', icon: Icons.fullscreen_rounded);
      } else {
        await defaultExitNativeFullscreen();
        _showOverlayHUD('Windowed', icon: Icons.fullscreen_exit_rounded);
      }
    } catch (_) {}
  }

  Future<void> _handleBack() async {
    if (_isFullscreen) {
      await _toggleFullscreen();
      return;
    }
    _saveCurrentProgress();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _saveCurrentProgress();
    if (_isFullscreen) {
      try {
        defaultExitNativeFullscreen();
      } catch (_) {}
    }
    _controlsTimer?.cancel();
    _overlayTimer?.cancel();
    _resumePromptTimer?.cancel();
    _lockIndicatorTimer?.cancel();
    _unlockButtonTimer?.cancel();
    _posSub.cancel();
    _durSub.cancel();
    _playingSub.cancel();
    _completedSub.cancel();
    _player.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _openCurrentVideo({Duration? startAt}) async {
    final currentFile = _playlist[_currentIndex];
    final isNetwork = currentFile.path.startsWith('http://') ||
        currentFile.path.startsWith('https://') ||
        currentFile.path.startsWith('rtsp://');

    final media = isNetwork ? Media(currentFile.path) : Media(currentFile.path);
    await _player.open(media, play: true);

    if (startAt != null && startAt > Duration.zero) {
      await _player.seek(startAt);
    } else {
      _checkResumePosition(currentFile);
    }
  }

  Future<void> _checkResumePosition(MediaFile file) async {
    try {
      final box = await Hive.openBox('settings_box');
      final savedMs = box.get('video_pos_${file.path}', defaultValue: 0) as int;
      if (savedMs > 5000 && mounted) {
        setState(() {
          _savedResumePosition = Duration(milliseconds: savedMs);
          _showResumePrompt = true;
        });
        _resumePromptTimer?.cancel();
        _resumePromptTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) setState(() => _showResumePrompt = false);
        });
      }
    } catch (_) {}
  }

  void _resumeSavedPosition() {
    if (_savedResumePosition != null) {
      _player.seek(_savedResumePosition!);
      _player.play();
      _showOverlayHUD('Resumed from ${_formatDuration(_savedResumePosition!)}', icon: Icons.history_rounded);
    }
    setState(() => _showResumePrompt = false);
  }

  void _restartFromStart() {
    _player.seek(Duration.zero);
    _player.play();
    _showOverlayHUD('Started from beginning', icon: Icons.replay_rounded);
    setState(() => _showResumePrompt = false);
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffle = !_isShuffle;
    });
    _showOverlayHUD(_isShuffle ? 'Shuffle: On' : 'Shuffle: Off', icon: Icons.shuffle_rounded);
  }

  void _toggleRepeat() {
    setState(() {
      if (_repeatMode == DesktopRepeatMode.all) {
        _repeatMode = DesktopRepeatMode.one;
        _showOverlayHUD('Loop: Current Video', icon: Icons.repeat_one_rounded);
      } else if (_repeatMode == DesktopRepeatMode.one) {
        _repeatMode = DesktopRepeatMode.off;
        _showOverlayHUD('Loop: Off', icon: Icons.repeat_rounded);
      } else {
        _repeatMode = DesktopRepeatMode.all;
        _showOverlayHUD('Loop: Entire Playlist', icon: Icons.repeat_rounded);
      }
    });
  }

  void _generateShuffledDeck() {
    _shuffledDeck = List.generate(_playlist.length, (i) => i)..shuffle();
    final pos = _shuffledDeck.indexOf(_currentIndex);
    if (pos != -1) {
      _shuffledDeck.removeAt(pos);
      _shuffledDeck.insert(0, _currentIndex);
      _shuffledDeckPointer = 0;
    } else {
      _shuffledDeckPointer = -1;
    }
  }

  void _playNext({bool isAuto = false}) {
    if (_playlist.isEmpty) return;

    if (isAuto) {
      final autoPlayFolder = Hive.box('settings_box').get('auto_play_folder', defaultValue: true) as bool;
      if (!autoPlayFolder && _repeatMode != DesktopRepeatMode.all) {
        return;
      }
    }

    if (_repeatMode == DesktopRepeatMode.one) {
      _player.seek(Duration.zero);
      _player.play();
      _showOverlayHUD('Looping current video', icon: Icons.repeat_one_rounded);
      return;
    }

    int nextIndex;
    if (_isShuffle) {
      if (_shuffledDeck.length != _playlist.length) {
        _generateShuffledDeck();
      }
      _shuffledDeckPointer++;
      if (_shuffledDeckPointer >= _shuffledDeck.length) {
        if (_repeatMode == DesktopRepeatMode.all) {
          _generateShuffledDeck();
          _shuffledDeckPointer = 0;
        } else {
          _showOverlayHUD('End of shuffled queue', icon: Icons.playlist_remove_rounded);
          return;
        }
      }
      nextIndex = _shuffledDeck[_shuffledDeckPointer];
    } else {
      nextIndex = _currentIndex + 1;
      if (nextIndex >= _playlist.length) {
        if (_repeatMode == DesktopRepeatMode.all) {
          nextIndex = 0; // Seamlessly loop the playlist again!
        } else {
          _showOverlayHUD('End of playlist', icon: Icons.playlist_remove_rounded);
          return;
        }
      }
    }

    setState(() {
      _currentIndex = nextIndex;
      _position = Duration.zero;
      _duration = Duration.zero;
      _rotation = 0;
    });
    _openCurrentVideo();
    _showOverlayHUD('Next: ${_playlist[_currentIndex].title}', icon: Icons.skip_next_rounded);
  }

  void _playPrevious() {
    if (_position.inSeconds > 3) {
      _player.seek(Duration.zero);
      _showOverlayHUD('Restarted', icon: Icons.replay_rounded);
      return;
    }
    if (_playlist.isEmpty) return;
    int prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      if (_repeatMode == DesktopRepeatMode.all) {
        prevIndex = _playlist.length - 1;
      } else {
        prevIndex = 0;
      }
    }
    setState(() {
      _currentIndex = prevIndex;
      _position = Duration.zero;
      _duration = Duration.zero;
      _rotation = 0;
    });
    _openCurrentVideo();
    _showOverlayHUD('Previous: ${_playlist[_currentIndex].title}', icon: Icons.skip_previous_rounded);
  }

  void _seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);
    _player.seek(clamped);
    _showOverlayHUD('${seconds > 0 ? '+' : ''}$seconds s', icon: seconds > 0 ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded);
    _startControlsTimer();
  }

  void _togglePlayPause() {
    _player.playOrPause();
    _showOverlayHUD(_isPlaying ? 'Paused' : 'Playing', icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded);
    _startControlsTimer();
  }

  void _showOverlayHUD(String text, {IconData? icon}) {
    _overlayTimer?.cancel();
    setState(() {
      _overlayText = text;
      _overlayIcon = icon;
    });
    _overlayTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _overlayText = null);
    });
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _adjustVolume(double delta) {
    final newVol = (_volume + delta).clamp(0.0, 150.0);
    setState(() {
      _volume = newVol;
      _isMuted = false;
    });
    _player.setVolume(newVol.clamp(0.0, 100.0));
    _showOverlayHUD('Volume: ${newVol.round()}%', icon: newVol > 100 ? Icons.volume_up_rounded : (newVol <= 0 ? Icons.volume_off_rounded : Icons.volume_down_rounded));
    _startControlsTimer();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _player.setVolume(_isMuted ? 0.0 : _volume.clamp(0.0, 100.0));
    _showOverlayHUD(_isMuted ? 'Muted' : 'Unmuted', icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded);
    _startControlsTimer();
  }

  void _adjustSpeed(double delta) {
    final newSpeed = (_speed + delta).clamp(0.25, 3.0);
    setState(() => _speed = newSpeed);
    _player.setRate(newSpeed);
    _showOverlayHUD('Speed: ${newSpeed.toStringAsFixed(2)}x', icon: Icons.speed_rounded);
    _startControlsTimer();
  }

  void _cycleRotation() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
    });
    _showOverlayHUD('Rotated $_rotation°', icon: Icons.screen_rotation_rounded);
    _startControlsTimer();
  }

  void _handleScrollDelta(Offset delta) {
    if (delta.dy.abs() > delta.dx.abs()) {
      // Vertical scroll: scroll down (dy > 0) -> lower vol; scroll up (dy < 0) -> raise vol
      final volDelta = delta.dy < 0 ? 4.0 : -4.0;
      _adjustVolume(volDelta);
    } else if (delta.dx.abs() > 0) {
      // Horizontal scroll: scroll right (dx > 0) -> forward; scroll left (dx < 0) -> rewind
      final deltaSec = delta.dx > 0 ? 5 : -5;
      _seekRelative(deltaSec);
    }
  }

  void _showTrackSelectionModal<T>({
    required String title,
    required IconData icon,
    required List<T> tracks,
    required T? currentTrack,
    required String Function(T) getName,
    String Function(T)? getSubtitle,
    required void Function(T) onSelect,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Dialog(
            backgroundColor: PulseColors.surface.withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: PulseColors.accentSecondary.withValues(alpha: 0.3)),
            ),
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: PulseColors.accentSecondary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: tracks.map((track) {
                          final isSelected = track == currentTrack;
                          final name = getName(track);
                          final sub = getSubtitle?.call(track);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? PulseColors.accentSecondary.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? PulseColors.accentSecondary
                                    : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              title: Text(
                                name,
                                style: TextStyle(
                                  color: isSelected ? PulseColors.accentSecondary : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: sub != null
                                  ? Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11))
                                  : null,
                              trailing: isSelected
                                  ? Icon(Icons.check_circle_rounded, color: PulseColors.accentSecondary, size: 20)
                                  : null,
                              onTap: () {
                                Navigator.of(ctx).pop();
                                onSelect(track);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleAudioTrackAction() {
    final tracks = _player.state.tracks.audio;
    if (tracks.isEmpty || tracks.length <= 1) {
      _showOverlayHUD('This video has only 1 audio track', icon: Icons.audiotrack_rounded);
      return;
    }
    _showTrackSelectionModal<AudioTrack>(
      title: 'Available Audio Tracks',
      icon: Icons.audiotrack_rounded,
      tracks: tracks,
      currentTrack: _player.state.track.audio,
      getName: (t) => t.language ?? t.title ?? 'Track ${tracks.indexOf(t) + 1}',
      getSubtitle: (t) => [
        if (t.channels != null) '${t.channels} channels',
        if (t.bitrate != null) '${(t.bitrate! / 1000).round()} kbps',
      ].join(' • '),
      onSelect: (t) {
        _player.setAudioTrack(t);
        final name = t.language ?? t.title ?? 'Track';
        _showOverlayHUD('Audio: $name', icon: Icons.audiotrack_rounded);
      },
    );
  }

  void _cycleAudioTrack() {
    final tracks = _player.state.tracks.audio;
    if (tracks.isEmpty || tracks.length <= 1) {
      _showOverlayHUD('Audio: 1 (Default Track)', icon: Icons.audiotrack_rounded);
      return;
    }

    final current = _player.state.track.audio;
    int currentIndex = tracks.indexWhere((t) => t.id == current.id);
    if (currentIndex == -1) currentIndex = 0;

    final nextIndex = (currentIndex + 1) % tracks.length;
    final nextTrack = tracks[nextIndex];

    _player.setAudioTrack(nextTrack);
    final name = nextTrack.language ?? nextTrack.title ?? 'Track ${nextIndex + 1}';
    _showOverlayHUD('Audio Track: $name (${nextIndex + 1}/${tracks.length})', icon: Icons.audiotrack_rounded);
  }

  void _cycleVideoTrack() {
    final tracks = _player.state.tracks.video;
    if (tracks.isEmpty) {
      _showOverlayHUD('Video Tracks: 1 (Default)', icon: Icons.videocam_rounded);
      return;
    }
    if (tracks.length <= 1) {
      final t = tracks.first;
      final info = t.title ?? '${t.w ?? "?"}x${t.h ?? "?"}';
      _showOverlayHUD('Video: $info (Only 1 Track)', icon: Icons.videocam_rounded);
      return;
    }

    final current = _player.state.track.video;
    int currentIndex = tracks.indexWhere((t) => t.id == current.id);
    if (currentIndex == -1) currentIndex = 0;

    final nextIndex = (currentIndex + 1) % tracks.length;
    final nextTrack = tracks[nextIndex];

    _player.setVideoTrack(nextTrack);
    final name = nextTrack.title ?? '${nextTrack.w ?? "?"}x${nextTrack.h ?? "?"}${nextTrack.fps != null ? " ${nextTrack.fps!.toStringAsFixed(0)}fps" : ""}';
    _showOverlayHUD('Video Track: $name (${nextIndex + 1}/${tracks.length})', icon: Icons.videocam_rounded);
  }

  void _cycleSubtitleTrack() {
    final subs = _player.state.tracks.subtitle;
    if (subs.isEmpty) {
      _showOverlayHUD('Subtitles: None Available', icon: Icons.subtitles_off_rounded);
      return;
    }

    final allSubs = [SubtitleTrack.no(), ...subs];
    final current = _player.state.track.subtitle;

    int currentIndex = allSubs.indexWhere((s) => s.id == current.id);
    if (currentIndex == -1) currentIndex = 0;

    final nextIndex = (currentIndex + 1) % allSubs.length;
    final nextSub = allSubs[nextIndex];

    _player.setSubtitleTrack(nextSub);
    final isOff = nextSub == SubtitleTrack.no() || nextSub.id == 'no';
    final name = isOff
        ? 'Off'
        : (nextSub.language ?? nextSub.title ?? 'Track $nextIndex');

    _showOverlayHUD(
      'Subtitles: $name${!isOff ? " ($nextIndex/${subs.length})" : ""}',
      icon: isOff ? Icons.subtitles_off_rounded : Icons.subtitles_rounded,
    );
  }

  void _handleVideoTrackAction() {
    final tracks = _player.state.tracks.video;
    if (tracks.isEmpty || tracks.length <= 1) {
      _showOverlayHUD('This video has only 1 video track', icon: Icons.videocam_rounded);
      return;
    }
    _showTrackSelectionModal<VideoTrack>(
      title: 'Available Video Tracks',
      icon: Icons.videocam_rounded,
      tracks: tracks,
      currentTrack: _player.state.track.video,
      getName: (t) => t.title ?? '${t.w ?? "?"}x${t.h ?? "?"}',
      getSubtitle: (t) => [
        if (t.fps != null) '${t.fps!.toStringAsFixed(0)} fps',
        if (t.bitrate != null) '${(t.bitrate! / 1000000).toStringAsFixed(1)} Mbps',
      ].join(' • '),
      onSelect: (t) {
        _player.setVideoTrack(t);
        _showOverlayHUD('Video Track Updated', icon: Icons.videocam_rounded);
      },
    );
  }

  void _handleSubtitleAction() {
    final subs = _player.state.tracks.subtitle;
    if (subs.isEmpty) {
      _showOverlayHUD('No subtitles available', icon: Icons.subtitles_off_rounded);
      return;
    }
    final allSubs = [SubtitleTrack.no(), ...subs];
    _showTrackSelectionModal<SubtitleTrack>(
      title: 'Available Subtitles',
      icon: Icons.subtitles_rounded,
      tracks: allSubs,
      currentTrack: _player.state.track.subtitle,
      getName: (t) => t == SubtitleTrack.no() ? 'Off' : (t.language ?? t.title ?? 'Subtitle Track ${allSubs.indexOf(t)}'),
      onSelect: (t) {
        _player.setSubtitleTrack(t);
        final name = t == SubtitleTrack.no() ? 'Off' : (t.language ?? t.title ?? 'Track');
        _showOverlayHUD('Subtitles: $name', icon: Icons.subtitles_rounded);
      },
    );
  }

  void _handleDoubleTap(Offset position, double width) {
    _toggleFullscreen();
  }

  String _formatDuration(Duration d) {
    final hrs = d.inHours;
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hrs > 0) return '$hrs:$mins:$secs';
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final currentFile = _playlist[_currentIndex];
    final size = MediaQuery.of(context).size;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        final key = event.logicalKey;
        final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

        if (key == LogicalKeyboardKey.keyK && !isCtrl) {
          _toggleLock();
          return;
        }

        if (_isLocked) {
          if (key == LogicalKeyboardKey.keyK) {
            _unlockScreen();
          } else {
            _showLockedFeedback();
          }
          return;
        }

        if (PulseShortcuts.matches(key, isCtrl, 'play_pause') || (key == LogicalKeyboardKey.space && !isCtrl)) {
          _togglePlayPause();
        } else if (PulseShortcuts.matches(key, isCtrl, 'seek_fwd_5') || (key == LogicalKeyboardKey.arrowRight && !isCtrl)) {
          _seekRelative(5);
        } else if (PulseShortcuts.matches(key, isCtrl, 'seek_back_5') || (key == LogicalKeyboardKey.arrowLeft && !isCtrl)) {
          _seekRelative(-5);
        } else if (PulseShortcuts.matches(key, isCtrl, 'seek_fwd_30') || (key == LogicalKeyboardKey.arrowRight && isCtrl)) {
          _seekRelative(30);
        } else if (PulseShortcuts.matches(key, isCtrl, 'seek_back_30') || (key == LogicalKeyboardKey.arrowLeft && isCtrl)) {
          _seekRelative(-30);
        } else if (PulseShortcuts.matches(key, isCtrl, 'vol_up') || (key == LogicalKeyboardKey.arrowUp && !isCtrl)) {
          _adjustVolume(5);
        } else if (PulseShortcuts.matches(key, isCtrl, 'vol_down') || (key == LogicalKeyboardKey.arrowDown && !isCtrl)) {
          _adjustVolume(-5);
        } else if (PulseShortcuts.matches(key, isCtrl, 'rotate_video') || (key == LogicalKeyboardKey.keyR && !isCtrl)) {
          _cycleRotation();
        } else if (PulseShortcuts.matches(key, isCtrl, 'toggle_mute') || (key == LogicalKeyboardKey.keyM && !isCtrl)) {
          _toggleMute();
        } else if (PulseShortcuts.matches(key, isCtrl, 'next_track') || (key == LogicalKeyboardKey.keyN && !isCtrl)) {
          _playNext();
        } else if (PulseShortcuts.matches(key, isCtrl, 'prev_track') || (key == LogicalKeyboardKey.keyP && !isCtrl)) {
          _playPrevious();
        } else if (PulseShortcuts.matches(key, isCtrl, 'cycle_audio') || (key == LogicalKeyboardKey.keyB && !isCtrl)) {
          _cycleAudioTrack();
        } else if (PulseShortcuts.matches(key, isCtrl, 'cycle_subs') || ((key == LogicalKeyboardKey.keyV || key == LogicalKeyboardKey.keyC) && !isCtrl)) {
          _cycleSubtitleTrack();
        } else if (PulseShortcuts.matches(key, isCtrl, 'cycle_video') || ((key == LogicalKeyboardKey.keyT || key == LogicalKeyboardKey.keyG) && !isCtrl)) {
          _cycleVideoTrack();
        } else if (PulseShortcuts.matches(key, isCtrl, 'fullscreen') || (key == LogicalKeyboardKey.keyF && !isCtrl)) {
          _toggleFullscreen();
        } else if (PulseShortcuts.matches(key, isCtrl, 'shuffle') || (key == LogicalKeyboardKey.keyS && !isCtrl)) {
          _toggleShuffle();
        } else if (PulseShortcuts.matches(key, isCtrl, 'loop') || (key == LogicalKeyboardKey.keyL && !isCtrl)) {
          _toggleRepeat();
        } else if (PulseShortcuts.matches(key, isCtrl, 'speed_up') || (key == LogicalKeyboardKey.bracketRight && !isCtrl)) {
          _adjustSpeed(0.25);
        } else if (PulseShortcuts.matches(key, isCtrl, 'speed_down') || (key == LogicalKeyboardKey.bracketLeft && !isCtrl)) {
          _adjustSpeed(-0.25);
        } else if (PulseShortcuts.matches(key, isCtrl, 'speed_normal') || (key == LogicalKeyboardKey.equal && !isCtrl)) {
          setState(() => _speed = 1.0);
          _player.setRate(1.0);
          _showOverlayHUD('Speed: 1.0x');
        } else if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.backspace) {
          _handleBack();
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_isLocked) {
            _showLockedFeedback();
            return;
          }
          _handleBack();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Listener(
            // Mouse wheel and Trackpad support: Scroll UP/DOWN -> Volume, Scroll LEFT/RIGHT -> Seek
            onPointerSignal: (pointerSignal) {
              if (_isLocked) return;
              if (pointerSignal is PointerScrollEvent) {
                _handleScrollDelta(pointerSignal.scrollDelta);
              }
            },
            onPointerPanZoomUpdate: (event) {
              if (_isLocked) return;
              if (event.pan.dy.abs() > 1.0 || event.pan.dx.abs() > 1.0) {
                _handleScrollDelta(event.pan);
              }
            },
            child: MouseRegion(
              onHover: (_) {
                if (_isLocked) return;
                if (!_showControls) {
                  setState(() => _showControls = true);
                }
                _startControlsTimer();
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Video Render Surface ─────────────────────────────
                  Center(
                    child: RotatedBox(
                      quarterTurns: (_rotation ~/ 90) % 4,
                      child: Video(
                        controller: _controller,
                        controls: NoVideoControls,
                      ),
                    ),
                  ),

                  // ── Background Tap & Double Tap Gesture Area ───────
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_isLocked) {
                          _showLockedFeedback();
                          return;
                        }
                        _togglePlayPause();
                        setState(() => _showControls = true);
                        _startControlsTimer();
                      },
                      onDoubleTapDown: (details) => _lastDoubleTapPosition = details.localPosition,
                      onDoubleTap: () {
                        if (_isLocked) {
                          _showLockedFeedback();
                          return;
                        }
                        if (_lastDoubleTapPosition != null) {
                          _handleDoubleTap(_lastDoubleTapPosition!, size.width);
                        }
                      },
                    ),
                  ),

                  // ── Center HUD Overlay Indicator ────────────────────
                  if (_overlayText != null)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: PulseColors.accentSecondary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_overlayIcon != null) ...[
                                  Icon(_overlayIcon, color: PulseColors.accentSecondary, size: 28),
                                  const SizedBox(width: 12),
                                ],
                                Text(
                                  _overlayText!,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Locked state: Center glowing lock indicator ──────────────────────
                  if (_isLocked && _showLockIndicator)
                    Center(
                      child: IgnorePointer(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141424).withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFFF2E63).withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF2E63).withValues(alpha: 0.3),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_rounded, color: Color(0xFFFF2E63), size: 36),
                                  SizedBox(height: 8),
                                  Text(
                                    "Screen Locked",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    "Press K or tap Unlock to restore controls",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Locked state: top-right corner floating unlock button ──────────────
                  if (_isLocked && _showUnlockButton)
                    Positioned(
                      top: 24,
                      right: 24,
                      child: SafeArea(
                        child: GestureDetector(
                          onTap: _unlockScreen,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141424).withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: const Color(0xFFFF2E63).withValues(alpha: 0.8), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF2E63).withValues(alpha: 0.35),
                                      blurRadius: 14,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_open_rounded, color: Color(0xFFFF2E63), size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      "Unlock",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Resume prompt banner ─────────────────────────────
                  if (_showResumePrompt && _savedResumePosition != null)
                    Positioned(
                      bottom: 96,
                      left: 24,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(
                              color: PulseColors.surface.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: PulseColors.accentSecondary.withValues(alpha: 0.5), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history_rounded, color: Color(0xFF00E5FF), size: 22),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "Resume Playback?",
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      "Left off at ${_formatDuration(_savedResumePosition!)}",
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: PulseColors.accentSecondary,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 4,
                                  ),
                                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                  label: Text("Resume (${_formatDuration(_savedResumePosition!)})",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: _resumeSavedPosition,
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.replay_rounded, size: 14),
                                  label: const Text("Start from Beginning",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                  onPressed: _restartFromStart,
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white54),
                                  tooltip: "Dismiss",
                                  onPressed: () => setState(() => _showResumePrompt = false),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Top Header Bar (Unified with working Back Button) ──
                  if (_showControls)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.85),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Back Button (Prominent & direct click)
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                              tooltip: "Back (Esc)",
                              onPressed: _handleBack,
                            ),
                            const SizedBox(width: 8),

                            // Video title and playlist counter
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentFile.title,
                                    style: PulseTypography.bodyLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_playlist.length > 1)
                                    Text(
                                      "Episode ${_currentIndex + 1} of ${_playlist.length}",
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                                    ),
                                ],
                              ),
                            ),

                            // Actions
                            IconButton(
                              icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
                              tooltip: "Rotate 90° (R)",
                              onPressed: _cycleRotation,
                            ),
                            GestureDetector(
                              onSecondaryTap: _handleVideoTrackAction,
                              child: IconButton(
                                icon: const Icon(Icons.videocam_rounded, color: Colors.white),
                                tooltip: "Cycle Video Track (T)",
                                onPressed: _cycleVideoTrack,
                              ),
                            ),
                            GestureDetector(
                              onSecondaryTap: _handleAudioTrackAction,
                              child: IconButton(
                                icon: const Icon(Icons.audiotrack_rounded, color: Colors.white),
                                tooltip: "Cycle Audio Track (B)",
                                onPressed: _cycleAudioTrack,
                              ),
                            ),
                            GestureDetector(
                              onSecondaryTap: _handleSubtitleAction,
                              child: IconButton(
                                icon: const Icon(Icons.subtitles_rounded, color: Colors.white),
                                tooltip: "Cycle Subtitles (V / C)",
                                onPressed: _cycleSubtitleTrack,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                              tooltip: "Add to Playlist",
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                  builder: (context) => AddToPlaylistSheet(mediaFile: currentFile),
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            // Like / Favorite button
                            AnimatedLikeButton(
                              track: currentFile,
                              size: 20,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                            const SizedBox(width: 4),
                            // Lock button
                            IconButton(
                              icon: Icon(_isLocked ? Icons.lock_rounded : Icons.lock_open_rounded, color: Colors.white),
                              tooltip: _isLocked ? "Unlock Screen (K)" : "Lock Screen (K)",
                              onPressed: _toggleLock,
                            ),
                            IconButton(
                              icon: Icon(
                                _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                color: Colors.white,
                              ),
                              tooltip: _isFullscreen ? "Exit Fullscreen (F)" : "Fullscreen (F)",
                              onPressed: _toggleFullscreen,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Bottom Playback Control Bar ─────────────────────
                  if (_showControls)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Scrubber Slider
                            Row(
                              children: [
                                Text(
                                  _formatDuration(_isDragging
                                      ? Duration(milliseconds: (_dragVal * _duration.inMilliseconds).round())
                                      : _position),
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Expanded(
                                  child: Listener(
                                    // VLC-style seek bar mouse wheel & trackpad scroll
                                    onPointerSignal: (pointerSignal) {
                                      if (pointerSignal is PointerScrollEvent) {
                                        final forward = pointerSignal.scrollDelta.dy < 0 || pointerSignal.scrollDelta.dx > 0;
                                        _seekRelative(forward ? 5 : -5);
                                      }
                                    },
                                    onPointerPanZoomUpdate: (event) {
                                      if (event.pan.dy.abs() > 1.0 || event.pan.dx.abs() > 1.0) {
                                        final forward = event.pan.dy < 0 || event.pan.dx > 0;
                                        _seekRelative(forward ? 5 : -5);
                                      }
                                    },
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                        activeTrackColor: PulseColors.accentPrimary,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: PulseColors.accentPrimary,
                                      ),
                                      child: Slider(
                                        value: _isDragging
                                            ? _dragVal.clamp(0.0, 1.0)
                                            : (_duration.inMilliseconds > 0
                                                ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                                                : 0.0),
                                        onChangeStart: (val) {
                                          setState(() {
                                            _isDragging = true;
                                            _dragVal = val;
                                          });
                                        },
                                        onChanged: (val) {
                                          setState(() {
                                            _dragVal = val;
                                          });
                                        },
                                        onChangeEnd: (val) {
                                          final target = Duration(milliseconds: (val * _duration.inMilliseconds).round());
                                          _player.seek(target);
                                          setState(() {
                                            _position = target;
                                            _isDragging = false;
                                          });
                                          _startControlsTimer();
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDuration(_duration),
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Playback Buttons & Volume
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Left: Volume & Speed Controls
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        _isMuted || _volume <= 0
                                            ? Icons.volume_off_rounded
                                            : (_volume > 100 ? Icons.volume_up_rounded : Icons.volume_down_rounded),
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      tooltip: "Mute (M)",
                                      onPressed: _toggleMute,
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: SliderTheme(
                                        data: SliderThemeData(
                                          trackHeight: 3,
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                          activeTrackColor: PulseColors.accentSecondary,
                                          inactiveTrackColor: Colors.white24,
                                          thumbColor: PulseColors.accentSecondary,
                                        ),
                                        child: Slider(
                                          value: _isMuted ? 0.0 : _volume.clamp(0.0, 150.0),
                                          min: 0.0,
                                          max: 150.0,
                                          onChanged: (val) {
                                            setState(() {
                                              _volume = val;
                                              _isMuted = false;
                                            });
                                            _player.setVolume(val.clamp(0.0, 100.0));
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Speed button
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: DropdownButton<double>(
                                        value: _speed,
                                        dropdownColor: PulseColors.surface,
                                        underline: const SizedBox(),
                                        isDense: true,
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        items: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((s) {
                                          return DropdownMenuItem<double>(
                                            value: s,
                                            child: Text('${s}x'),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _speed = val);
                                            _player.setRate(val);
                                            _showOverlayHUD('Speed: ${val}x', icon: Icons.speed_rounded);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),

                                // Center: Shuffle | Previous | Play-Pause | Next | Repeat (Loop)
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.shuffle_rounded,
                                        color: _isShuffle ? PulseColors.accentSecondary : Colors.white38,
                                        size: 22,
                                      ),
                                      tooltip: "Shuffle (S)",
                                      onPressed: _toggleShuffle,
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28),
                                      tooltip: "Previous (P)",
                                      onPressed: _playPrevious,
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 26),
                                      tooltip: "Replay 10s (←)",
                                      onPressed: () => _seekRelative(-10),
                                    ),
                                    const SizedBox(width: 6),
                                    PulseInteractivePlayButton(
                                      isPlaying: _isPlaying,
                                      onTap: _togglePlayPause,
                                      size: 48,
                                      gradient: LinearGradient(
                                        colors: [PulseColors.accentPrimary, PulseColors.accentSecondary],
                                      ),
                                      iconColor: Colors.white,
                                      glowColor: PulseColors.accentPrimary,
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 26),
                                      tooltip: "Skip 10s (→)",
                                      onPressed: () => _seekRelative(10),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                                      tooltip: "Next (N)",
                                      onPressed: _playNext,
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: Icon(
                                        _repeatMode == DesktopRepeatMode.one
                                            ? Icons.repeat_one_rounded
                                            : Icons.repeat_rounded,
                                        color: _repeatMode != DesktopRepeatMode.off
                                            ? PulseColors.accentSecondary
                                            : Colors.white38,
                                        size: 22,
                                      ),
                                      tooltip: _repeatMode == DesktopRepeatMode.one
                                          ? "Loop: Current (L)"
                                          : (_repeatMode == DesktopRepeatMode.all
                                              ? "Loop: Entire Playlist (L)"
                                              : "Loop: Off (L)"),
                                      onPressed: _toggleRepeat,
                                    ),
                                  ],
                                ),

                                // Right: Shortcuts Guide
                                IconButton(
                                  icon: const Icon(Icons.help_outline_rounded, color: Colors.white70, size: 20),
                                  tooltip: "Keyboard Shortcuts",
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        backgroundColor: PulseColors.surface,
                                        title: const Text('Keyboard & Mouse Controls', style: TextStyle(color: Colors.white)),
                                        content: const Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('• Space: Play / Pause', style: TextStyle(color: Colors.white70)),
                                            Text('• Scroll Up / Down: Volume Control', style: TextStyle(color: Colors.white70)),
                                            Text('• Scroll Left / Right: Seek 5s', style: TextStyle(color: Colors.white70)),
                                            Text('• Double Click (Left/Right): Seek 10s', style: TextStyle(color: Colors.white70)),
                                            Text('• Double Click (Center): Play / Pause', style: TextStyle(color: Colors.white70)),
                                            Text('• Arrow Keys: Left/Right (Seek), Up/Down (Volume)', style: TextStyle(color: Colors.white70)),
                                            Text('• N / P: Next / Previous Track', style: TextStyle(color: Colors.white70)),
                                            Text('• R: Rotate 90°', style: TextStyle(color: Colors.white70)),
                                            Text('• M: Mute / Unmute', style: TextStyle(color: Colors.white70)),
                                            Text('• B / V: Audio / Subtitles', style: TextStyle(color: Colors.white70)),
                                            Text('• S: Toggle Shuffle', style: TextStyle(color: Colors.white70)),
                                            Text('• L: Toggle Loop (Playlist / Track / Off)', style: TextStyle(color: Colors.white70)),
                                            Text('• Esc / Backspace: Exit Player', style: TextStyle(color: Colors.white70)),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Got it'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
