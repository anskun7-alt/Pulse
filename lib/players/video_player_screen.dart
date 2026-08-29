import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/media_file.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../services/playback_service.dart';

enum VideoRepeatMode { off, all, one }
enum ScreenOrientationMode { auto, landscape, portrait }

class VideoPlayerScreen extends StatefulWidget {
  final MediaFile file;
  final List<MediaFile>? playlist;
  final Duration? initialPosition;

  const VideoPlayerScreen({
    Key? key,
    required this.file,
    this.playlist,
    this.initialPosition,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with WidgetsBindingObserver {
  late BetterPlayerController _betterPlayerController;
  late Box _settingsBox;
  final GlobalKey _screenshotKey = GlobalKey();

  bool _isInitialized = false;
  bool _showControls = true;
  bool _isLocked = false;
  bool _isFirstInit = true;
  bool _handedOffToBackground = false;
  Duration? _overrideInitialPosition;
  double _volume = 1.0;

  StreamSubscription? _bgPlayerStateSub;
  StreamSubscription? _bgPositionSub;

  Future<void> _cancelLocalSubscriptions() async {
    try {
      await _bgPlayerStateSub?.cancel();
      _bgPlayerStateSub = null;
      await _bgPositionSub?.cancel();
      _bgPositionSub = null;
    } catch (_) {}
  }

  // FIX: Start at 1.0 (fully transparent overlay) so the video is never dimmed on load
  double _brightness = 1.0;
  double _playbackSpeed = 1.0;

  // Zoom Modes: 'Fit' | 'Fill' | 'Stretch'
  String _zoomMode = 'Fit';
  double _scale = 1.0;

  // Real-time smooth dragging seeker
  bool _isDraggingSlider = false;
  double _dragValue = 0.0;

  // Overlay HUD indicators
  String? _overlayType;
  double _overlayValue = 0.0;
  Timer? _overlayTimer;
  Timer? _controlsTimer;
  Timer? _debounceTimer;

  // Subtitle and Audio Track
  List<String> _subtitleFiles = [];
  int _currentSubtitleIndex = -1;
  double _subtitleDelay = 0.0;
  double _subtitleFontSize = 18.0;
  Color _subtitleColor = Colors.white;

  // Error handling
  String? _errorMessage;

  // Video rotation
  int _rotation = 0; // in multiples of 90, always 0/90/180/270
  Offset? _lastDoubleTapPosition;
  bool _justDoubleTapped = false;
  Timer? _doubleTapGuardTimer;

  // Pinch to zoom
  double _pinchScale = 1.0;

  // Sleep timer
  Timer? _sleepTimer;
  int _sleepTimerMinutes = 0;

  // A-B Loop
  Duration? _loopStart;
  Duration? _loopEnd;
  bool _isLooping = false;

  // Frame by frame
  static const double _frameDuration = 1.0 / 30.0;

  // Playlist Navigation
  late List<MediaFile> _playlist;
  late int _currentIndex;
  bool _isShuffle = false;
  // Default to repeat all videos for continuous playback.
  VideoRepeatMode _repeatMode = VideoRepeatMode.all;

  // Real-time updates
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;

  // Swipe seek
  Duration? _dragStartVideoPosition;
  double _dragStartDx = 0.0;
  Duration? _targetSeekPosition;

  // Left/Right side vertical swipe overlays
  bool _isLeftDrag = false;
  bool _showSideVolumeBar = false;
  bool _showSideBrightnessBar = false;
  Timer? _sideBarTimer;

  // Screen orientation mode
  ScreenOrientationMode _screenOrientationMode = ScreenOrientationMode.auto;

  // FIX: Track whether player was playing before backgrounding
  bool _wasPlayingBeforeBackground = false;

  // Helper to hand off video playback to background audio
  void _handoffToBackground() {
    if (_isPlaying) {
      _betterPlayerController.pause();
      final currentFile = _playlist[_currentIndex];
      final currentPosition = _betterPlayerController.videoPlayerController?.value.position ?? Duration.zero;
      _handedOffToBackground = true;
      PlaybackService.instance.playTrack(
        currentFile,
        newQueue: _playlist,
        startPosition: currentPosition,
        forceAudio: true,
      );
    }
  }

  @override
  void initState() {
    super.initState();

    _playlist = widget.playlist ?? [widget.file];
    _currentIndex = _playlist.indexWhere((f) => f.path == widget.file.path);
    if (_currentIndex == -1) {
      _currentIndex = 0;
      _playlist = [widget.file];
    }

    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initPlayer();
  }

  // FIX: Properly handle background/foreground transitions
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!_isInitialized) return;

    switch (state) {
      case AppLifecycleState.inactive:
        // When app becomes inactive, attempt PiP if video is playing
        if (_isPlaying) {
          _enterPipIfPossible();
        }
        break;
      case AppLifecycleState.paused:
        // Hand off playing video to background audio playback
        _wasPlayingBeforeBackground = _isPlaying;
        if (_isPlaying) {
          _betterPlayerController.pause();
          final currentFile = _playlist[_currentIndex];
          final currentPosition = _betterPlayerController.videoPlayerController?.value.position ?? Duration.zero;
          
          _handedOffToBackground = true;
          PlaybackService.instance.playTrack(
            currentFile,
            newQueue: _playlist,
            startPosition: currentPosition,
            forceAudio: true,
          );
        }
        break;
      case AppLifecycleState.resumed:
        if (_handedOffToBackground) {
          _handedOffToBackground = false;
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            final playbackService = PlaybackService.instance;
            final track = playbackService.currentTrack.value;
            if (track != null) {
              final newIdx = _playlist.indexWhere((f) => f.path == track.path);
              if (newIdx != -1) {
                final currentPosition = playbackService.position.value;
                final isPlaying = playbackService.isPlaying.value;
                
                playbackService.player.setVolume(0.0);
                
                if (newIdx == _currentIndex) {
                  _betterPlayerController.seekTo(currentPosition).then((_) {
                    if (isPlaying) {
                      _betterPlayerController.play();
                      playbackService.player.play();
                    } else {
                      _betterPlayerController.pause();
                      playbackService.player.pause();
                    }
                  });
                } else {
                  _overrideInitialPosition = currentPosition;
                  _playVideoAtIndex(newIdx, autoPlay: isPlaying);
                }
              }
            }
          });
        } else if (_wasPlayingBeforeBackground) {
          _wasPlayingBeforeBackground = false;
          _betterPlayerController.play();
          PlaybackService.instance.player.setVolume(0.0);
          PlaybackService.instance.player.play();
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }



  void _enterPipIfPossible() async {
    if (Platform.isAndroid) {
      try {
        if (_betterPlayerController.betterPlayerGlobalKey != null) {
          await _betterPlayerController.enablePictureInPicture(_betterPlayerController.betterPlayerGlobalKey!);
        } else {
          debugPrint('Error entering PiP: betterPlayerGlobalKey is null');
        }
      } catch (e) {
        debugPrint('Error entering PiP: $e');
      }
    }
  }

  void _applyOrientation(double aspectRatio) {
    if (_screenOrientationMode == ScreenOrientationMode.auto) {
      if (aspectRatio > 1.0) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    } else if (_screenOrientationMode == ScreenOrientationMode.landscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void _setRotation(int newRotation) {
    setState(() {
      _rotation = newRotation;
    });
    _applyZoomMode();
  }

  DateTime _lastStateUpdateTime = DateTime.now();

  void _onPlayerStateChanged() {
    if (!mounted) return;
    final controller = _betterPlayerController.videoPlayerController;
    if (controller == null) return;

    final value = controller.value;
    final position = value.position;
    final duration = value.duration;
    final isPlaying = value.isPlaying;

    // Bidirectional synchronization to background player
    if (!_handedOffToBackground) {
      final bgPlayer = PlaybackService.instance.player;
      if (isPlaying != bgPlayer.playing) {
        if (isPlaying) {
          bgPlayer.play();
        } else {
          bgPlayer.pause();
        }
      }
      final bgPos = bgPlayer.position;
      if ((position - bgPos).abs().inSeconds > 2) {
        bgPlayer.seek(position);
      }
    }

    bool shouldUpdate = false;
    final now = DateTime.now();

    if (isPlaying != _isPlaying || duration != _totalDuration) {
      shouldUpdate = true;
    } else if (position != _currentPosition) {
      // Throttle position updates to ~1 time a second to completely prevent heavy UI lag
      if (now.difference(_lastStateUpdateTime).inMilliseconds >= 1000) {
        shouldUpdate = true;
      }
    }

    if (shouldUpdate) {
      _lastStateUpdateTime = now;
      setState(() {
        _currentPosition = position;
        _totalDuration = duration ?? Duration.zero;
        _isPlaying = isPlaying;
      });
    }
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
      if (_isLooping && _loopStart != null && _loopEnd != null) {
        final position = _betterPlayerController.videoPlayerController?.value.position;
        if (position != null && position >= _loopEnd!) {
          _betterPlayerController.seekTo(_loopStart!);
        }
      }
    } else if (event.betterPlayerEventType == BetterPlayerEventType.finished) {
      _handleVideoCompleted();
    } else if (event.betterPlayerEventType == BetterPlayerEventType.initialized) {
      final duration = _betterPlayerController.videoPlayerController?.value.duration;
      if (duration != null) {
        setState(() {
          _totalDuration = duration;
        });
        try {
          final box = Hive.box('media_files_box');
          final current = _playlist[_currentIndex];
          final updated = current.copyWith(duration: duration);
          box.put(updated.path, updated.toMap());
        } catch (e) {
          debugPrint('Failed to update video duration in cache: $e');
        }
      }
    }
  }

  void _handleVideoCompleted() {
    if (_repeatMode == VideoRepeatMode.one) {
      _betterPlayerController.seekTo(Duration.zero);
      _betterPlayerController.play();
    } else {
      Future.delayed(Duration.zero, () {
        if (mounted) {
          _playNextVideo(autoPlay: true);
        }
      });
    }
  }

  Future<void> _playVideoAtIndex(int index, {bool autoPlay = false}) async {
    if (index < 0 || index >= _playlist.length) return;

    if (_isInitialized) {
      _betterPlayerController.removeEventsListener(_onPlayerEvent);
      _betterPlayerController.videoPlayerController?.removeListener(_onPlayerStateChanged);
      
      // Unbind controller reference
      if (PlaybackService.instance.activeVideoController == _betterPlayerController) {
        PlaybackService.instance.activeVideoController = null;
        PlaybackService.instance.onVideoNext = null;
        PlaybackService.instance.onVideoPrevious = null;
      }
      _cancelLocalSubscriptions();

      _betterPlayerController.dispose();
      setState(() {
        _isInitialized = false;
        _errorMessage = null;
        _loopStart = null;
        _loopEnd = null;
        _isLooping = false;
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        _isPlaying = false;
      });
    }

    _currentIndex = index;
    await _initPlayer();

    // Explicit play() call guarantees autoplay even if BetterPlayer's autoPlay
    // config doesn't fire on mid-session re-initialisation.
    if (autoPlay) {
      // Wait a tick for the controller to be ready
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) _betterPlayerController.play();
    }
  }

  void _playNextVideo({bool autoPlay = false}) {
    if (_playlist.isEmpty) return;
    int nextIndex;
    if (_isShuffle) {
      final random = Random();
      nextIndex = random.nextInt(_playlist.length);
    } else {
      nextIndex = _currentIndex + 1;
      if (nextIndex >= _playlist.length) {
        if (_repeatMode == VideoRepeatMode.all) {
          nextIndex = 0;
        } else {
          // No next video and repeat is off — stop here
          if (autoPlay) return;
          nextIndex = 0;
        }
      }
    }
    _playVideoAtIndex(nextIndex, autoPlay: autoPlay);
  }

  void _playPreviousVideo() {
    if (_playlist.isEmpty) return;
    int prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      prevIndex = _repeatMode == VideoRepeatMode.all ? _playlist.length - 1 : _playlist.length - 1;
    }
    _playVideoAtIndex(prevIndex);
  }

  void _cycleScreenOrientation() {
    setState(() {
      if (_screenOrientationMode == ScreenOrientationMode.auto) {
        _screenOrientationMode = ScreenOrientationMode.landscape;
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        _showOverlayHUD('Orientation', 1.0);
      } else if (_screenOrientationMode == ScreenOrientationMode.landscape) {
        _screenOrientationMode = ScreenOrientationMode.portrait;
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        _showOverlayHUD('Orientation', 2.0);
      } else {
        _screenOrientationMode = ScreenOrientationMode.auto;
        final size = _betterPlayerController.videoPlayerController?.value.size;
        final aspectRatio = (size != null && size.width > 0 && size.height > 0)
            ? size.width / size.height
            : 1.0;
        _applyOrientation(aspectRatio);
        _showOverlayHUD('Orientation', 0.0);
      }
    });
  }

  void _triggerSideBar(bool isLeft) {
    setState(() {
      if (isLeft) {
        _showSideBrightnessBar = true;
        _showSideVolumeBar = false;
      } else {
        _showSideVolumeBar = true;
        _showSideBrightnessBar = false;
      }
    });

    _sideBarTimer?.cancel();
    _sideBarTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showSideBrightnessBar = false;
          _showSideVolumeBar = false;
        });
      }
    });
  }

  Future<void> _initPlayer() async {
    _settingsBox = Hive.box('settings_box');

    final currentFile = _playlist[_currentIndex];

    await _loadExternalSubtitles();

    try {
      BetterPlayerConfiguration betterPlayerConfiguration = BetterPlayerConfiguration(
        autoPlay: true,
        autoDetectFullscreenDeviceOrientation: false,
        autoDetectFullscreenAspectRatio: true,
        // Use BoxFit.contain to avoid cropping the video sides.
        fit: BoxFit.contain,
        handleLifecycle: true,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
        ),
      );

      BetterPlayerDataSource dataSource;
      final startAt = _overrideInitialPosition ?? (_isFirstInit ? widget.initialPosition : null);
      _isFirstInit = false;
      _overrideInitialPosition = null;

      if (currentFile.path.startsWith('http') ||
          currentFile.path.startsWith('https') ||
          currentFile.path.startsWith('assets/')) {
        dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          currentFile.path,
        );
} else {
        dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.file,
          currentFile.path,
        );
      }
      _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
      await _betterPlayerController.setupDataSource(dataSource);

      // Bind controller reference
      PlaybackService.instance.activeVideoController = _betterPlayerController;
      PlaybackService.instance.onVideoNext = () {
        _playNextVideo(autoPlay: true);
      };
      PlaybackService.instance.onVideoPrevious = _playPreviousVideo;

      // Apply initial volume (clamped to 1.0 for video controller)
      _volume = PlaybackService.instance.volumeScale.value;
      _betterPlayerController.setVolume(_volume > 1.0 ? 1.0 : _volume);

      // Cancel any existing background subscriptions before re-registering
      await _cancelLocalSubscriptions();

      // Listen to background player changes
      _bgPlayerStateSub = PlaybackService.instance.player.playerStateStream.listen((state) {
        if (!mounted || !_isInitialized) return;
        final bgPlaying = state.playing;
        final videoPlaying = _betterPlayerController.videoPlayerController?.value.isPlaying ?? false;
        if (bgPlaying != videoPlaying) {
          if (bgPlaying) {
            _betterPlayerController.play();
          } else {
            _betterPlayerController.pause();
          }
        }
      });

      _bgPositionSub = PlaybackService.instance.player.positionStream.listen((pos) {
        if (!mounted || !_isInitialized || _isDraggingSlider) return;
        final videoPos = _betterPlayerController.videoPlayerController?.value.position ?? Duration.zero;
        if ((pos - videoPos).abs().inSeconds > 2) {
          _betterPlayerController.seekTo(pos);
        }
      });

      _settingsBox.put('last_played', currentFile.path);
      _settingsBox.put('last_played_time', DateTime.now().millisecondsSinceEpoch);

      final videoPlayerController = _betterPlayerController.videoPlayerController;
    if (videoPlayerController != null) {
      videoPlayerController.addListener(_onPlayerStateChanged);
      // Seek to the provided start position if any
      if (startAt != null) {
        // Delay briefly to ensure the player is ready
        Future.microtask(() async {
          await Future.delayed(const Duration(milliseconds: 100));
          await _betterPlayerController.seekTo(startAt);
        });
      }

      void checkSizeAndRotate() {
          if (!mounted) return;
          if (videoPlayerController.value.size != null) {
            final videoSize = videoPlayerController.value.size!;
            if (videoSize.width > 0 && videoSize.height > 0) {
              final aspectRatio = videoSize.width / videoSize.height;
              _applyOrientation(aspectRatio);
              _applyZoomMode();
              videoPlayerController.removeListener(checkSizeAndRotate);
            }
          }
        }

        if (videoPlayerController.value.size != null &&
            videoPlayerController.value.size!.width > 0) {
          checkSizeAndRotate();
        } else {
          videoPlayerController.addListener(checkSizeAndRotate);
        }
      }

      setState(() {
        _isInitialized = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final videoPlayerController = _betterPlayerController.videoPlayerController;
        if (videoPlayerController != null && videoPlayerController.value.size != null) {
          final videoSize = videoPlayerController.value.size!;
          if (videoSize.width > 0 && videoSize.height > 0) {
            final aspectRatio = videoSize.width / videoSize.height;
            _applyOrientation(aspectRatio);
            _applyZoomMode();
          }
        }
      });

      _startControlsTimer();
      _betterPlayerController.addEventsListener(_onPlayerEvent);
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      setState(() {
        _errorMessage = 'Failed to load video: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // FIX: Restore ALL orientations so the folder/home screens are not
    // permanently locked to portrait after leaving the video player.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Unbind controller reference
    if (PlaybackService.instance.activeVideoController == _betterPlayerController) {
      PlaybackService.instance.activeVideoController = null;
      PlaybackService.instance.onVideoNext = null;
      PlaybackService.instance.onVideoPrevious = null;
    }
    _cancelLocalSubscriptions();

    _betterPlayerController.removeEventsListener(_onPlayerEvent);
    _betterPlayerController.videoPlayerController?.removeListener(_onPlayerStateChanged);
    _betterPlayerController.dispose();
    _overlayTimer?.cancel();
    _controlsTimer?.cancel();
    _debounceTimer?.cancel();
    _sleepTimer?.cancel();
    _sideBarTimer?.cancel();
    _doubleTapGuardTimer?.cancel();
    super.dispose();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_isLocked) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    if (_isLocked) return;
    // FIX: Don't toggle controls if a double-tap just fired — the double-tap
    // gesture also triggers onTap, which would immediately undo the HUD.
    if (_justDoubleTapped) {
      return;
    }
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    }
  }

  void _showOverlayHUD(String type, double value) {
    setState(() {
      _overlayType = type;
      _overlayValue = value;
    });

    _overlayTimer?.cancel();
    // Use 1.2s for seek HUD so it's readable, 2s for volume/brightness
    final duration = (type == 'Seek')
        ? const Duration(milliseconds: 1200)
        : const Duration(milliseconds: 2000);
    _overlayTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _overlayType = null;
        });
      }
    });
  }

  void _adjustVolume(double delta) {
    if (_isLocked) return;
    setState(() {
      _volume = (_volume + delta).clamp(0.0, 1.5);
      PlaybackService.instance.setVolumeScale(_volume);
    });
    _showOverlayHUD('Volume', _volume);
    _triggerSideBar(false);
  }

  void _adjustBrightness(double delta) {
    if (_isLocked) return;
    setState(() {
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
    });
    _showOverlayHUD('Brightness', _brightness);
    _triggerSideBar(true);
  }

  void _doubleTapSeek(Offset localPosition, double screenWidth) async {
    if (_isLocked) return;
    _justDoubleTapped = true;
    // Clear guard after 600ms (enough to prevent the tap-up triggering _toggleControls)
    _doubleTapGuardTimer?.cancel();
    _doubleTapGuardTimer = Timer(const Duration(milliseconds: 600), () {
      _justDoubleTapped = false;
    });

    final currentPosition =
        _betterPlayerController.videoPlayerController?.value.position ?? Duration.zero;

    if (localPosition.dx > screenWidth / 2) {
      _showOverlayHUD('Seek', 10.0);
      await _betterPlayerController.seekTo(currentPosition + const Duration(seconds: 10));
    } else {
      _showOverlayHUD('Seek', -10.0);
      await _betterPlayerController.seekTo(currentPosition - const Duration(seconds: 10));
    }
    // Ensure controls stay visible after a seek
    setState(() => _showControls = true);
    _startControlsTimer();
  }

  void _applyZoomMode() {
    if (!mounted || !_isInitialized) return;
    final videoController = _betterPlayerController.videoPlayerController;
    if (videoController == null || videoController.value.size == null) return;

    final videoSize = videoController.value.size!;
    if (videoSize.width <= 0 || videoSize.height <= 0) return;

    final originalAspect = videoSize.width / videoSize.height;

    final mediaQuery = MediaQuery.of(context);
    final isRotatedLandscape = _rotation % 180 != 0;
    final screenAspect = isRotatedLandscape
        ? mediaQuery.size.height / mediaQuery.size.width
        : mediaQuery.size.width / mediaQuery.size.height;

    switch (_zoomMode) {
      case 'Fit':
        _betterPlayerController.setOverriddenFit(BoxFit.contain);
        _betterPlayerController.setOverriddenAspectRatio(originalAspect);
        break;
      case 'Fill':
        _betterPlayerController.setOverriddenFit(BoxFit.cover);
        _betterPlayerController.setOverriddenAspectRatio(screenAspect);
        break;
      case 'Stretch':
        _betterPlayerController.setOverriddenFit(BoxFit.fill);
        _betterPlayerController.setOverriddenAspectRatio(screenAspect);
        break;
      case '16:9':
        _betterPlayerController.setOverriddenFit(BoxFit.contain);
        _betterPlayerController.setOverriddenAspectRatio(16 / 9);
        break;
      case '4:3':
        _betterPlayerController.setOverriddenFit(BoxFit.contain);
        _betterPlayerController.setOverriddenAspectRatio(4 / 3);
        break;
      case '1:1':
        _betterPlayerController.setOverriddenFit(BoxFit.contain);
        _betterPlayerController.setOverriddenAspectRatio(1.0);
        break;
      default:
        _betterPlayerController.setOverriddenFit(BoxFit.contain);
        _betterPlayerController.setOverriddenAspectRatio(originalAspect);
    }
  }

  void _cycleZoom() {
    setState(() {
      if (_zoomMode == 'Fit') {
        _zoomMode = 'Fill';
        _scale = 1.0;
      } else if (_zoomMode == 'Fill') {
        _zoomMode = 'Stretch';
        _scale = 1.0;
      } else {
        _zoomMode = 'Fit';
        _scale = 1.0;
      }
    });
    _applyZoomMode();
  }

  void _showSelectionMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: PulseColors.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(color: const Color(0xFF1E1E30), width: 1),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Video Options', style: PulseTypography.displayMedium),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.white),
                title: Text('Share Video', style: PulseTypography.bodyLarge),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: Colors.white),
                title: Text('Video Info', style: PulseTypography.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _showVideoInfo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.subtitles_rounded, color: Colors.white),
                title: Text('Subtitles', style: PulseTypography.bodyLarge),
                trailing: Text(
                  _subtitleFiles.isEmpty ? 'None' : '${_subtitleFiles.length} available',
                  style: PulseTypography.bodySmall.copyWith(color: Colors.white60),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSubtitleSelection();
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                title: Text('Add to Playlist', style: PulseTypography.bodyLarge),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVideoInfo() {
    final currentFile = _playlist[_currentIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PulseColors.surface,
        title: Text('Video Information', style: PulseTypography.displayMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: ${currentFile.title}', style: PulseTypography.bodyLarge),
            const SizedBox(height: 8),
            Text('Path: ${currentFile.path}', style: PulseTypography.bodyLarge),
            const SizedBox(height: 8),
            Text('Duration: ${_formatDuration(_totalDuration)}', style: PulseTypography.bodyLarge),
            const SizedBox(height: 8),
            Text('Subtitles: ${_subtitleFiles.length} external files found',
                style: PulseTypography.bodyLarge),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: PulseTypography.bodyLarge),
          ),
        ],
      ),
    );
  }

  Future<void> _loadExternalSubtitles() async {
    try {
      final currentFile = _playlist[_currentIndex];
      final videoFile = File(currentFile.path);
      final videoDir = videoFile.parent;
      final videoName = currentFile.path.split(Platform.pathSeparator).last;
      final baseName = videoName.substring(0, videoName.lastIndexOf('.'));

      final subtitleExtensions = ['srt', 'vtt', 'ass', 'ssa', 'sub'];

      setState(() {
        _subtitleFiles.clear();
        _currentSubtitleIndex = -1;
      });

      for (final ext in subtitleExtensions) {
        final subtitlePath = '${videoDir.path}${Platform.pathSeparator}$baseName.$ext';
        final subtitleFile = File(subtitlePath);
        if (await subtitleFile.exists()) {
          setState(() {
            _subtitleFiles.add(subtitlePath);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading external subtitles: $e');
    }
  }

  void _showSubtitleSelection() {
    if (_subtitleFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'No external subtitle files found. Place .srt, .vtt, .ass, .ssa, or .sub files in the same folder as the video.'),
          backgroundColor: PulseColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: PulseColors.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(color: const Color(0xFF1E1E30), width: 1),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Select Subtitle', style: PulseTypography.displayMedium),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(
                  _currentSubtitleIndex == -1 ? Icons.check_circle : Icons.circle_outlined,
                  color: _currentSubtitleIndex == -1
                      ? PulseColors.accentSecondary
                      : Colors.white60,
                ),
                title: Text('Off', style: PulseTypography.bodyLarge),
                onTap: () {
                  setState(() => _currentSubtitleIndex = -1);
                  Navigator.pop(context);
                },
              ),
              ...List.generate(_subtitleFiles.length, (index) {
                final fileName =
                    _subtitleFiles[index].split(Platform.pathSeparator).last;
                return ListTile(
                  leading: Icon(
                    _currentSubtitleIndex == index
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: _currentSubtitleIndex == index
                        ? PulseColors.accentSecondary
                        : Colors.white60,
                  ),
                  title: Text(fileName, style: PulseTypography.bodyLarge),
                  onTap: () {
                    setState(() => _currentSubtitleIndex = index);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final int hours = d.inHours;
    final int minutes = d.inMinutes.remainder(60);
    final int seconds = d.inSeconds.remainder(60);
    final String hh = hours > 0 ? hours.toString().padLeft(2, '0') + ':' : '';
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return '$hh$mm:$ss';
  }

  void _showAddToPlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PulseColors.surface,
        title: Text('Add to Playlist', style: PulseTypography.displayMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite_border, color: Colors.white),
              title: Text('Favorites', style: PulseTypography.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Added to Favorites'),
                    backgroundColor: PulseColors.success,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.watch_later, color: Colors.white),
              title: Text('Watch Later', style: PulseTypography.bodyLarge),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Added to Watch Later'),
                    backgroundColor: PulseColors.success,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: PulseTypography.bodyLarge),
          ),
        ],
      ),
    );
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes > 0) {
      setState(() => _sleepTimerMinutes = minutes);
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        _betterPlayerController.pause();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sleep timer: Playback stopped'),
            backgroundColor: PulseColors.accentSecondary,
          ),
        );
        setState(() => _sleepTimerMinutes = 0);
      });
    } else {
      setState(() => _sleepTimerMinutes = 0);
    }
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: PulseColors.surface.withOpacity(0.95),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    border: Border.all(color: const Color(0xFF1E1E30), width: 1),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Playback Settings', style: PulseTypography.displayMedium),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 12),

                      // Video Rotation
                      Text('Video Rotation', style: PulseTypography.bodyLarge),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.rotate_left, color: Colors.white),
                            onPressed: () {
                              _setRotation((_rotation - 90 + 360) % 360);
                              setSheetState(() {});
                            },
                          ),
                          const Spacer(),
                          Text('${_rotation}°', style: PulseTypography.bodyLarge),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.rotate_right, color: Colors.white),
                            onPressed: () {
                              _setRotation((_rotation + 90) % 360);
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Aspect Ratio / Crop
                      Text('Aspect Ratio / Crop', style: PulseTypography.bodyLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children:
                            ['Fit', 'Fill', 'Stretch', '16:9', '4:3', '1:1'].map((mode) {
                          final isSel = _zoomMode == mode;
                          return ChoiceChip(
                            label: Text(mode),
                            selected: isSel,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _zoomMode = mode;
                                  _scale = 1.0;
                                });
                                _applyZoomMode();
                                setSheetState(() {});
                              }
                            },
                            selectedColor: PulseColors.accentSecondary,
                            backgroundColor: PulseColors.surfaceHigh,
                            labelStyle:
                                TextStyle(color: isSel ? Colors.black : Colors.white),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Reset to Defaults
                      ElevatedButton.icon(
                        onPressed: () {
                          _setRotation(0);
                          setState(() {
                            _zoomMode = 'Fit';
                            _scale = 1.0;
                            _volume = 1.0;
                            PlaybackService.instance.setVolumeScale(1.0);
                            _brightness = 1.0;
                            _playbackSpeed = 1.0;
                          });
                          _applyZoomMode();
                          setSheetState(() {});
                        },
                        icon: const Icon(Icons.refresh, color: Colors.black),
                        label: Text('Reset to Defaults', style: PulseTypography.bodyLarge),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: PulseColors.accentSecondary),
                      ),

                      const SizedBox(height: 24),

                      // Playback Speed
                      Text('Playback Speed', style: PulseTypography.bodyLarge),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                          final isSel = _playbackSpeed == speed;
                          return ChoiceChip(
                            label: Text('${speed}x'),
                            selected: isSel,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _playbackSpeed = speed;
                                  _betterPlayerController.setSpeed(speed);
                                });
                                setSheetState(() {});
                              }
                            },
                            selectedColor: PulseColors.accentSecondary,
                            backgroundColor: PulseColors.surfaceHigh,
                            labelStyle:
                                TextStyle(color: isSel ? Colors.black : Colors.white),
                          );
                        }).toList(),
                      ),

                      // Volume
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.volume_up_rounded,
                                color: _volume > 1.0 ? Colors.orangeAccent : Colors.white70,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Slider(
                                  value: _volume,
                                  min: 0.0,
                                  max: 1.5,
                                  activeColor: _volume > 1.0 ? Colors.orangeAccent : PulseColors.accentSecondary,
                                  onChanged: (val) {
                                    setState(() {
                                      _volume = val;
                                      PlaybackService.instance.setVolumeScale(val);
                                    });
                                    setSheetState(() {});
                                  },
                                ),
                              ),
                              Text(
                                '${(_volume * 100).round()}%',
                                style: TextStyle(
                                  color: _volume > 1.0 ? Colors.orangeAccent : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (_volume > 1.0)
                            const Padding(
                              padding: EdgeInsets.only(left: 36, bottom: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'Volume boosted: May cause distortion',
                                    style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),


                      const SizedBox(height: 24),

                      // Brightness
                      Row(
                        children: [
                          const Icon(Icons.brightness_6_rounded, color: Colors.white70),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Slider(
                              value: _brightness,
                              min: 0.0,
                              max: 1.0,
                              activeColor: PulseColors.accentSecondary,
                              onChanged: (val) {
                                setState(() => _brightness = val);
                                setSheetState(() {});
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Sleep Timer
                      Text('Sleep Timer', style: PulseTypography.bodyLarge),
                      const SizedBox(height: 8),
                      if (_sleepTimerMinutes > 0)
                        Text('Active: $_sleepTimerMinutes min',
                            style: PulseTypography.bodySmall
                                .copyWith(color: PulseColors.success)),
                      Wrap(
                        spacing: 8,
                        children: [0, 15, 30, 45, 60].map((minutes) {
                          final isSel = _sleepTimerMinutes == minutes;
                          return ChoiceChip(
                            label: Text(minutes == 0 ? 'Off' : '${minutes}m'),
                            selected: isSel,
                            onSelected: (selected) {
                              _setSleepTimer(minutes);
                              setSheetState(() {});
                            },
                            selectedColor: PulseColors.accentSecondary,
                            backgroundColor: PulseColors.surfaceHigh,
                            labelStyle:
                                TextStyle(color: isSel ? Colors.black : Colors.white),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // A-B Loop
                      Text('A-B Loop', style: PulseTypography.bodyLarge),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _loopStart = _betterPlayerController
                                    .videoPlayerController?.value.position;
                                if (_loopEnd != null &&
                                    _loopEnd! <= _loopStart!) {
                                  _loopEnd = null;
                                }
                              });
                              setSheetState(() {});
                            },
                            icon: const Icon(Icons.flag, color: Colors.black, size: 16),
                            label: Text('Set A', style: PulseTypography.bodySmall),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _loopStart != null
                                  ? PulseColors.accentSecondary
                                  : PulseColors.surfaceHigh,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _loopEnd = _betterPlayerController
                                    .videoPlayerController?.value.position;
                                if (_loopStart != null &&
                                    _loopEnd! > _loopStart!) {
                                  _isLooping = true;
                                }
                              });
                              setSheetState(() {});
                            },
                            icon: const Icon(Icons.flag, color: Colors.black, size: 16),
                            label: Text('Set B', style: PulseTypography.bodySmall),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _loopEnd != null
                                  ? PulseColors.accentSecondary
                                  : PulseColors.surfaceHigh,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _loopStart = null;
                                _loopEnd = null;
                                _isLooping = false;
                              });
                              setSheetState(() {});
                            },
                            icon: const Icon(Icons.clear, color: Colors.black, size: 16),
                            label: Text('Clear', style: PulseTypography.bodySmall),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: PulseColors.danger),
                          ),
                        ],
                      ),
                      if (_isLooping)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Looping: ${_formatDuration(_loopStart!)} - ${_formatDuration(_loopEnd!)}',
                            style: PulseTypography.bodySmall
                                .copyWith(color: PulseColors.success),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Subtitle Delay
                      Text('Subtitle Delay', style: PulseTypography.bodyLarge),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _subtitleDelay =
                                    (_subtitleDelay - 0.5).clamp(-5.0, 5.0);
                              });
                              setSheetState(() {});
                            },
                          ),
                          const Spacer(),
                          Text('${_subtitleDelay.toStringAsFixed(1)}s',
                              style: PulseTypography.bodyLarge),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _subtitleDelay =
                                    (_subtitleDelay + 0.5).clamp(-5.0, 5.0);
                              });
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _exitPlayer() async {
    final wasPlaying = _isInitialized && (_betterPlayerController.videoPlayerController?.value.isPlaying ?? false);
    Duration currentPosition = Duration.zero;
    if (wasPlaying) {
      currentPosition = _betterPlayerController.videoPlayerController?.value.position ?? Duration.zero;
    }

    if (_isInitialized) {
      _betterPlayerController.pause();
    }
    // Force portrait orientation immediately to trigger clean transition
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (wasPlaying) {
      final currentFile = _playlist[_currentIndex];
      PlaybackService.instance.playTrack(
        currentFile,
        newQueue: _playlist,
        startPosition: currentPosition,
        forceAudio: true,
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _takeScreenshot() async {
    try {
      final boundary = _screenshotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('RepaintBoundary context not found');
      }
      
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to obtain image byte data');
      }
      
      final buffer = byteData.buffer.asUint8List();
      
      final directory = Platform.isAndroid 
          ? Directory('/storage/emulated/0/Pictures/Pulse')
          : await getApplicationDocumentsDirectory();
      
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/screenshot_$timestamp.png');
      await file.writeAsBytes(buffer);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Screenshot saved: ${file.path.split('/').last}'),
            backgroundColor: PulseColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error taking screenshot: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to take screenshot: $e'),
            backgroundColor: PulseColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: PulseColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: PulseColors.danger, size: 64),
                const SizedBox(height: 16),
                Text('Video Error', style: PulseTypography.displayMedium),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: PulseTypography.bodyLarge
                      .copyWith(color: PulseColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _errorMessage = null);
                    _initPlayer();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: PulseColors.accentSecondary),
                  child: Text('Retry', style: PulseTypography.bodyLarge),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: PulseColors.accentSecondary),
              const SizedBox(height: 16),
              Text(
                'Loading video...',
                style: PulseTypography.bodyLarge
                    .copyWith(color: PulseColors.textPrimary),
              ),
            ],
          ),
        ),
      );
    }

    final size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async {
        if (_isLocked) {
          _showOverlayHUD('Lock', 1.0);
          return false;
        }
        await _exitPlayer();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video ──────────────────────────────────────────────────────────
            Center(
              child: GestureDetector(
                onScaleStart: (_) => setState(() => _pinchScale = _scale),
                onScaleUpdate: (details) => setState(() {
                  _scale = (_pinchScale * details.scale).clamp(0.5, 3.0);
                }),
                onScaleEnd: (_) => setState(() => _pinchScale = 1.0),
                child: RepaintBoundary(
                  key: _screenshotKey,
                  child: Transform.scale(
                    scale: _scale,
                    // FIX: Use RotatedBox instead of Transform.rotate.
                    // RotatedBox tells Flutter's layout engine to swap dimensions,
                    // so the video fills the correct area at any rotation angle.
                    // Transform.rotate only visually rotates without updating layout,
                    // causing the half-white-screen bug when SystemChrome is also active.
                    child: RotatedBox(
                      quarterTurns: (_rotation ~/ 90) % 4,
                      child: BetterPlayer(controller: _betterPlayerController),
                    ),
                  ),
                ),
              ),
            ),

            // ── Brightness dimmer overlay ──────────────────────────────────────
            // FIX: withOpacity(1.0 - _brightness). When _brightness==1.0 → opacity 0 (invisible).
            // When _brightness==0.0 → opacity 1.0 (fully black).
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(1.0 - _brightness),
                ),
              ),
            ),

            // ── Gesture zones ──────────────────────────────────────────────────
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                // FIX: Store position on down, then call seek on the actual double-tap
                // event. This lets _toggleControls check _justDoubleTapped and bail
                // out, preventing the HUD from being instantly destroyed.
                onDoubleTapDown: (details) =>
                    _lastDoubleTapPosition = details.localPosition,
                onDoubleTap: () {
                  if (_lastDoubleTapPosition != null) {
                    _doubleTapSeek(_lastDoubleTapPosition!, size.width);
                  }
                },
                onLongPressStart: (_) {
                  if (_isLocked) return;
                  _showSelectionMenu();
                },
                onHorizontalDragStart: (details) {
                  if (_isLocked) return;
                  _isDraggingSlider = true;
                  _dragStartVideoPosition = _currentPosition;
                  _dragStartDx = details.localPosition.dx;
                  _targetSeekPosition = _currentPosition;
                },
                onHorizontalDragUpdate: (details) {
                  if (_isLocked || !_isDraggingSlider || _dragStartVideoPosition == null)
                    return;
                  final dx = details.localPosition.dx;
                  final diffDx = dx - _dragStartDx;
                  final maxSeekRange = _totalDuration.inSeconds > 0
                      ? _totalDuration.inSeconds.toDouble()
                      : 300.0;
                  final seekDeltaSeconds =
                      (diffDx / size.width) * min(maxSeekRange, 120.0);
                  final targetSeconds =
                      (_dragStartVideoPosition!.inSeconds + seekDeltaSeconds)
                          .clamp(0.0, _totalDuration.inSeconds.toDouble());
                  setState(() {
                    _targetSeekPosition =
                        Duration(seconds: targetSeconds.toInt());
                  });
                  _showOverlayHUD(
                      'Seek', targetSeconds - _dragStartVideoPosition!.inSeconds);
                },
                onHorizontalDragEnd: (_) async {
                  if (_isDraggingSlider && _targetSeekPosition != null) {
                    await _betterPlayerController.seekTo(_targetSeekPosition!);
                  }
                  _isDraggingSlider = false;
                  _dragStartVideoPosition = null;
                  _targetSeekPosition = null;
                  // Clear the seek HUD immediately on drag end
                  _overlayTimer?.cancel();
                  setState(() => _overlayType = null);
                  // Show controls so user can see current position
                  setState(() => _showControls = true);
                  _startControlsTimer();
                },
                onVerticalDragStart: (details) {
                  if (_isLocked) return;
                  _isLeftDrag = details.localPosition.dx < size.width / 2;
                  _triggerSideBar(_isLeftDrag);
                },
                onVerticalDragUpdate: (details) {
                  if (_isLocked) return;
                  final delta = -details.primaryDelta! / size.height;
                  _debounceTimer?.cancel();
                  _debounceTimer = Timer(const Duration(milliseconds: 8), () {
                    if (_isLeftDrag) {
                      _adjustBrightness(delta);
                    } else {
                      _adjustVolume(delta);
                    }
                  });
                },
                child: const SizedBox.expand(),
              ),
            ),

            // ── Side brightness bar ────────────────────────────────────────────
            if (_showSideBrightnessBar)
              Positioned(
                left: 12,
                top: size.height * 0.25,
                bottom: size.height * 0.25,
                width: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    color: Colors.white24,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          height: (size.height * 0.5) * _brightness,
                          color: PulseColors.accentSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Side volume bar ────────────────────────────────────────────────
            if (_showSideVolumeBar)
              Positioned(
                right: 12,
                top: size.height * 0.25,
                bottom: size.height * 0.25,
                width: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    color: Colors.white24,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          height: (size.height * 0.5) * (_volume / 1.5),
                          color: _volume > 1.0 ? Colors.orangeAccent : PulseColors.accentSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── HUD overlay ────────────────────────────────────────────────────
            if (_overlayType != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                            blurRadius: 16,
                          )
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _overlayType == 'Volume'
                                    ? Icons.volume_up_rounded
                                    : _overlayType == 'Brightness'
                                        ? Icons.brightness_6_rounded
                                        : _overlayType == 'Orientation'
                                            ? Icons.screen_rotation_rounded
                                            : _overlayType == 'Shuffle'
                                                ? Icons.shuffle_rounded
                                                : _overlayType == 'Repeat'
                                                    ? Icons.repeat_rounded
                                                    : _overlayValue > 0
                                                        ? Icons.fast_forward_rounded
                                                        : Icons.fast_rewind_rounded,
                                color: _overlayType == 'Volume' && _overlayValue > 1.0 ? Colors.orangeAccent : Colors.white,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _overlayType == 'Volume'
                                    ? '${(_overlayValue * 100).round()}%'
                                    : _overlayType == 'Brightness'
                                        ? '${(_overlayValue * 100).round()}%'
                                        : _overlayType == 'Orientation'
                                            ? (_overlayValue == 1.0
                                                ? 'Landscape Lock'
                                                : _overlayValue == 2.0
                                                    ? 'Portrait Lock'
                                                    : 'Auto Rotate')
                                            : _overlayType == 'Shuffle'
                                                ? (_overlayValue == 1.0
                                                    ? 'Shuffle On'
                                                    : 'Shuffle Off')
                                                : _overlayType == 'Repeat'
                                                    ? (_overlayValue == 1.0
                                                        ? 'Repeat All'
                                                        : _overlayValue == 2.0
                                                            ? 'Repeat One'
                                                            : 'Repeat Off')
                                                    : '${_overlayValue > 0 ? '+' : ''}${_overlayValue.round()}s',
                                style: TextStyle(
                                  color: _overlayType == 'Volume' && _overlayValue > 1.0 ? Colors.orangeAccent : Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black54,
                                      offset: Offset(0, 2),
                                      blurRadius: 8,
                                    ),
                                    Shadow(
                                      color: Colors.black38,
                                      offset: Offset(0, 4),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_overlayType == 'Volume' && _overlayValue > 1.0) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Volume boosted: May cause distortion',
                                  style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Controls (MX-Player style, visible when not locked) ───────────
            if (_showControls && !_isLocked) ...[

              // Top gradient scrim for readability
              Positioned(
                top: 0, left: 0, right: 0,
                height: 140,
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom gradient scrim
              Positioned(
                bottom: 0, left: 0, right: 0,
                height: 160,
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Top bar: back | title | music | subtitle | HW | ⋮ ───────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                            onPressed: _exitPlayer,
                          ),
                          Expanded(
                            child: Text(
                              _playlist[_currentIndex].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Music / audio track icon
                          IconButton(
                            icon: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
                            tooltip: 'Audio track',
                            onPressed: () {},
                          ),
                          // Subtitle toggle
                          IconButton(
                            icon: Icon(
                              Icons.subtitles_rounded,
                              color: _currentSubtitleIndex >= 0
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white,
                              size: 20,
                            ),
                            tooltip: 'Subtitles',
                            onPressed: _showSubtitleSelection,
                          ),
                          // HW/SW decoder toggle badge
                          GestureDetector(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'HW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // More menu
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 22),
                            onPressed: () => _showSelectionMenu(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Action pills row + Lock button ───────────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 72,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    // Subtitle on/off
                    _VideoPillButton(
                      icon: _currentSubtitleIndex >= 0
                          ? Icons.subtitles_rounded
                          : Icons.subtitles_off_rounded,
                      active: _currentSubtitleIndex >= 0,
                      onTap: _showSubtitleSelection,
                    ),
                    const SizedBox(width: 8),
                    // Shuffle
                    _VideoPillButton(
                      icon: Icons.shuffle_rounded,
                      active: _isShuffle,
                      onTap: () => setState(() {
                        _isShuffle = !_isShuffle;
                        _showOverlayHUD('Shuffle', _isShuffle ? 1.0 : 0.0);
                      }),
                    ),
                    const SizedBox(width: 8),
                    // Repeat
                    _VideoPillButton(
                      icon: _repeatMode == VideoRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      active: _repeatMode != VideoRepeatMode.off,
                      onTap: () => setState(() {
                        if (_repeatMode == VideoRepeatMode.off) {
                          _repeatMode = VideoRepeatMode.all;
                          _showOverlayHUD('Repeat', 1.0);
                        } else if (_repeatMode == VideoRepeatMode.all) {
                          _repeatMode = VideoRepeatMode.one;
                          _showOverlayHUD('Repeat', 2.0);
                        } else {
                          _repeatMode = VideoRepeatMode.off;
                          _showOverlayHUD('Repeat', 0.0);
                        }
                      }),
                    ),
                    const SizedBox(width: 8),
                    // Orientation cycle
                    _VideoPillButton(
                      icon: _screenOrientationMode == ScreenOrientationMode.auto
                          ? Icons.screen_rotation_rounded
                          : _screenOrientationMode == ScreenOrientationMode.landscape
                              ? Icons.screen_lock_landscape_rounded
                              : Icons.screen_lock_portrait_rounded,
                      active: _screenOrientationMode != ScreenOrientationMode.auto,
                      onTap: _cycleScreenOrientation,
                    ),
                    const SizedBox(width: 8),
                    // Screenshot
                    _VideoPillButton(
                      icon: Icons.camera_alt_rounded,
                      onTap: _takeScreenshot,
                    ),
                    const SizedBox(width: 8),
                    // Settings / more
                    _VideoPillButton(
                      icon: Icons.settings_rounded,
                      onTap: () => _showSettingsBottomSheet(context),
                    ),
                    const Spacer(),
                    // Lock button — always at the far right of the pill row
                    GestureDetector(
                      onTap: () => setState(() {
                        _isLocked = true;
                        _showControls = false;
                        _controlsTimer?.cancel();
                      }),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Bottom unified controls card ──
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress bar row
                          Row(
                            children: [
                              Text(
                                _isDraggingSlider
                                    ? _formatDuration(Duration(seconds: _dragValue.toInt()))
                                    : _formatDuration(_currentPosition),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3.0,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                    activeTrackColor: const Color(0xFF00E5FF),
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: Colors.white,
                                    overlayColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                                  ),
                                  child: Slider(
                                    value: _isDraggingSlider
                                        ? _dragValue.clamp(0.0, max(1.0, _totalDuration.inSeconds.toDouble()))
                                        : _currentPosition.inSeconds.toDouble().clamp(0.0, max(1.0, _totalDuration.inSeconds.toDouble())),
                                    min: 0.0,
                                    max: max(1.0, _totalDuration.inSeconds.toDouble()),
                                    onChangeStart: (val) => setState(() {
                                      _isDraggingSlider = true;
                                      _dragValue = val;
                                    }),
                                    onChanged: (val) => setState(() => _dragValue = val),
                                    onChangeEnd: (val) async {
                                      await _betterPlayerController.seekTo(Duration(seconds: val.toInt()));
                                      setState(() => _isDraggingSlider = false);
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                _formatDuration(_totalDuration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Controls icons row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 22),
                                tooltip: 'Picture in picture',
                                onPressed: _enterPipIfPossible,
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28),
                                    onPressed: _playPreviousVideo,
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      if (_isPlaying) {
                                        await _betterPlayerController.pause();
                                      } else {
                                        await _betterPlayerController.play();
                                      }
                                    },
                                    child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF00E5FF),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.black,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                                    onPressed: () => _playNextVideo(),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.aspect_ratio_rounded, color: Colors.white, size: 22),
                                tooltip: 'Aspect ratio',
                                onPressed: _cycleZoom,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // ── Locked state: centred unlock button only ───────────────────────
            if (_isLocked)
              Center(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isLocked = false;
                    _showControls = true;
                    _startControlsTimer();
                  }),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.redAccent, width: 1.5),
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.redAccent, size: 24),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Helper: circular pill button for the action row ──────────────────────────
class _VideoPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _VideoPillButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00E5FF).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? const Color(0xFF00E5FF) : Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: active ? const Color(0xFF00E5FF) : Colors.white,
          size: 18,
        ),
      ),
    );
  }
}