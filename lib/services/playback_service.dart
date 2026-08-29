import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'media_scanner.dart';

import '../models/media_file.dart';
import '../services/lyrics_service.dart';
import 'color_service.dart';
import 'playlist_service.dart';
import '../app.dart';
import '../players/audio_player_screen.dart';
import '../players/video_player_screen.dart';

enum RepeatMode { off, all, one }

class PlaybackService {
  static final PlaybackService instance = PlaybackService._internal();
  PlaybackService._internal();

  late AudioPlayer _audioPlayer;
  
  // Declared nullable to prevent late initialization and dispose leaks
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _currentIndexSubscription;
  StreamSubscription? _interruptionSubscription;
  StreamSubscription? _playbackEventSubscription;

  final ValueNotifier<MediaFile?> currentTrack = ValueNotifier<MediaFile?>(null);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<List<MediaFile>> queue = ValueNotifier<List<MediaFile>>([]);
  final ValueNotifier<int> queueIndex = ValueNotifier<int>(-1);
  final ValueNotifier<bool> isShuffle = ValueNotifier<bool>(false);
  final ValueNotifier<RepeatMode> repeatMode =
      ValueNotifier<RepeatMode>(RepeatMode.off);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<int> sleepSecondsRemaining = ValueNotifier<int>(0);
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(1.0);

  // Volume boost scale: 0.0 to 1.5. Synchronized across foreground/background sessions.
  final ValueNotifier<double> volumeScale = ValueNotifier<double>(1.0);
  AndroidLoudnessEnhancer? _loudnessEnhancer;

  // Synchronization hooks for active video controller controls
  BetterPlayerController? activeVideoController;
  VoidCallback? onVideoNext;
  VoidCallback? onVideoPrevious;
  bool get isPlayingVideoOnScreen => activeVideoController != null;

  ConcatenatingAudioSource? _playlist;

  bool _audioScreenOpen = false;
  bool _videoScreenOpen = false;
  bool _wasPlayingBeforeInterruption = false;
  bool _lastIncludeVideo = false;

  Timer? _sleepTimer;
  Timer? _heartbeatTimer;
  List<MediaFile> _originalQueue = [];
  final Map<String, bool> _artExistsCache = {};

  final List<double> speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  AudioPlayer get player => _audioPlayer;
  bool get audioScreenOpen => _audioScreenOpen;
  bool get videoScreenOpen => _videoScreenOpen;

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------
  Future<void> _cancelSubscriptions() async {
    try {
      await _interruptionSubscription?.cancel();
      await _playbackEventSubscription?.cancel();
      await _playerStateSubscription?.cancel();
      await _currentIndexSubscription?.cancel();
      await _positionSubscription?.cancel();
      await _durationSubscription?.cancel();
    } catch (_) {}
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (isPlaying.value && !_audioPlayer.playing) {
        debugPrint('[Heartbeat] Recovery triggered: restarting background player.');
        try {
          await _audioPlayer.play();
        } catch (e) {
          debugPrint('[Heartbeat] Recovery play failed: $e');
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> setVolumeScale(double scale) async {
    final clamped = scale.clamp(0.0, 1.5);
    volumeScale.value = clamped;
    
    // Save to Hive
    final settingsBox = Hive.box('settings_box');
    await settingsBox.put('volume_scale', clamped);

    // Apply to players
    if (clamped <= 1.0) {
      await _audioPlayer.setVolume(clamped);
      if (Platform.isAndroid && _loudnessEnhancer != null) {
        await _loudnessEnhancer!.setTargetGain(0.0);
      }
    } else {
      // Scale above 100%: keep standard volume at 1.0, boost gain
      await _audioPlayer.setVolume(1.0);
      if (Platform.isAndroid && _loudnessEnhancer != null) {
        // Map 1.0-1.5 linearly to 0.0-12.0 dB target gain
        final gainDb = (clamped - 1.0) * 24.0; // 0.5 * 24 = 12 dB max
        await _loudnessEnhancer!.setTargetGain(gainDb);
      }
    }

    // Sync to active video controller if present
    if (activeVideoController != null) {
      final videoVol = clamped > 1.0 ? 1.0 : clamped;
      activeVideoController!.setVolume(videoVol);
    }
  }

  Future<void> _updateTrackDurationInCache(MediaFile track, Duration dur) async {
    try {
      final updatedTrack = track.copyWith(duration: dur);
      if (currentTrack.value?.path == track.path) {
        currentTrack.value = updatedTrack;
      }
      
      // Update in MediaScanner list
      final scannerFiles = List<MediaFile>.from(MediaScanner.instance.allFiles.value);
      final idx = scannerFiles.indexWhere((f) => f.path == track.path);
      if (idx != -1) {
        scannerFiles[idx] = updatedTrack;
        MediaScanner.instance.allFiles.value = scannerFiles;
      }

      // Update in Hive box
      final box = Hive.box('media_files_box');
      if (box.isOpen) {
        await box.put(track.path, updatedTrack.toMap());
      }
      debugPrint('[PlaybackService] Lazy cached audio duration for ${track.title}: $dur');
    } catch (e) {
      debugPrint('Failed to update track duration in cache: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------
  Future<void> init() async {
    await _cancelSubscriptions();

    if (Platform.isAndroid) {
      _loudnessEnhancer = AndroidLoudnessEnhancer();
      final pipeline = AudioPipeline(androidAudioEffects: [_loudnessEnhancer!]);
      _audioPlayer = AudioPlayer(audioPipeline: pipeline);
      await _loudnessEnhancer!.setEnabled(true);
    } else {
      _audioPlayer = AudioPlayer();
    }

    // Load and apply saved volume scale preference
    final settingsBox = Hive.box('settings_box');
    final savedVolume = settingsBox.get('volume_scale', defaultValue: 1.0) as double;
    await setVolumeScale(savedVolume);

    if (Platform.isAndroid) {
      try {
        await Permission.notification.request();
      } catch (e) {
        debugPrint('Notification permission request error: $e');
      }
    }

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      await session.setActive(true);

      _interruptionSubscription =
          session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              await _audioPlayer.setVolume(0.2);
              break;
            case AudioInterruptionType.pause:
              if (_audioPlayer.playing) {
                _wasPlayingBeforeInterruption = true;
                await _audioPlayer.pause();
              }
              break;
            case AudioInterruptionType.unknown:
              await _audioPlayer.setVolume(0.8);
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              await setMaxVolume();
              break;
            case AudioInterruptionType.pause:
              if (_wasPlayingBeforeInterruption) {
                _wasPlayingBeforeInterruption = false;
                await _audioPlayer.play();
              }
              break;
            case AudioInterruptionType.unknown:
              await setMaxVolume();
              break;
          }
        }
      });
    }

    _playbackEventSubscription = _audioPlayer.playbackEventStream
        .listen((_) {}, onError: (Object e, StackTrace st) {
      debugPrint('Playback event error: $e');
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Playback error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    });

    _playerStateSubscription =
        _audioPlayer.playerStateStream.listen((state) {
      isPlaying.value = state.playing;
      if (state.playing) {
        _startHeartbeat();
      } else {
        _stopHeartbeat();
      }
      if (state.processingState == ProcessingState.completed) {
        if (repeatMode.value == RepeatMode.off) {
          isPlaying.value = false;
          _audioPlayer.pause();
          _audioPlayer.seek(Duration.zero, index: 0);
        }
      }
    });

    _currentIndexSubscription =
        _audioPlayer.currentIndexStream.listen((index) {
      if (index != null &&
          _playlist != null &&
          index < _playlist!.children.length) {
        try {
          final audioSource =
              _playlist!.children[index] as UriAudioSource;
          final mediaItem = audioSource.tag as MediaItem;
          final matchedIndex =
              queue.value.indexWhere((t) => _isSamePath(t.path, mediaItem.id));
          if (matchedIndex != -1) {
            queueIndex.value = matchedIndex;
            final track = queue.value[matchedIndex];
            currentTrack.value = track;
            try {
              if (track.albumArtPath != null &&
                  File(track.albumArtPath!).existsSync()) {
                ColorService.instance
					.updateFromImage(FileImage(File(track.albumArtPath!)));
              } else {
                ColorService.instance.reset();
              }
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('Index sync error: $e');
        }
      }
    });

    _positionSubscription =
        _audioPlayer.positionStream.listen((pos) {
      position.value = pos;
    });

    _durationSubscription =
        _audioPlayer.durationStream.listen((dur) {
      if (dur != null) {
        duration.value = dur;
        final track = currentTrack.value;
        if (track != null && !track.isVideo && track.duration == Duration.zero && dur > Duration.zero) {
          _updateTrackDurationInCache(track, dur);
        }
      }
    });
  }

  bool _isSamePath(String p1, String p2) {
    return p1.replaceAll('\\', '/').toLowerCase() == p2.replaceAll('\\', '/').toLowerCase();
  }

  // ---------------------------------------------------------------------------
  // VIDEO NAVIGATION GUARD
  // ---------------------------------------------------------------------------
  void navigateToVideo(List<MediaFile> videoQueue, MediaFile track) {
    if (_videoScreenOpen) return;
    _videoScreenOpen = true;
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              VideoPlayerScreen(file: track, playlist: videoQueue),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            final tween =
                Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.fastLinearToSlowEaseIn));
            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
        ),
      ).then((_) {
        _videoScreenOpen = false;
      });
    } else {
      _videoScreenOpen = false;
    }
  }

  // ---------------------------------------------------------------------------
  // PLAY TRACK
  // ---------------------------------------------------------------------------
  bool _isQueueEqual(List<MediaFile> q1, List<MediaFile> q2) {
    if (q1.length != q2.length) return false;
    for (int i = 0; i < q1.length; i++) {
      if (!_isSamePath(q1[i].path, q2[i].path)) return false;
    }
    return true;
  }

  Future<void> playTrack(MediaFile track,
      {List<MediaFile>? newQueue, Duration? startPosition, bool forceAudio = false}) async {
    bool queueChanged = false;
    int targetIndex = 0;

    final bool includeVideo = track.isVideo && !forceAudio;

    if (newQueue != null) {
      if (!_isQueueEqual(queue.value, newQueue)) {
        queueChanged = true;
        if (isShuffle.value) {
          _originalQueue = List<MediaFile>.from(newQueue);
          final list = List<MediaFile>.from(newQueue)
            ..removeWhere((t) => _isSamePath(t.path, track.path));
          list.shuffle();
          list.insert(0, track);
          queue.value = list;
          targetIndex = 0;
        } else {
          _originalQueue = List<MediaFile>.from(newQueue);
          queue.value = newQueue;
          targetIndex = newQueue.indexWhere((t) => _isSamePath(t.path, track.path));
        }
      } else {
        targetIndex = queue.value.indexWhere((t) => _isSamePath(t.path, track.path));
        if (targetIndex == -1) targetIndex = 0;
      }
    } else if (!queue.value.any((t) => _isSamePath(t.path, track.path))) {
      queueChanged = true;
      queue.value = [track];
      targetIndex = 0;
    } else {
      targetIndex =
          queue.value.indexWhere((t) => _isSamePath(t.path, track.path));
    }

    if (includeVideo != _lastIncludeVideo) {
      queueChanged = true;
      _lastIncludeVideo = includeVideo;
    }

    // Fire-and-forget: Log play in the background
    unawaited(Future(() async {
      try {
        await PlaylistService.instance.logPlay(track.path);
      } catch (_) {}
    }));

    if (track.isVideo && !forceAudio) {
      // Background notifications session sync:
      // Load video in the background player with volume 0.0, and play it.
      await _audioPlayer.setVolume(0.0);
      if (Platform.isAndroid && _loudnessEnhancer != null) {
        await _loudnessEnhancer!.setTargetGain(0.0);
      }

      isLoading.value = true;
      try {
        if (queueChanged || _playlist == null) {
          await _updatePlaylist(targetIndex, initialPosition: startPosition, includeVideo: true);
        } else {
          await _audioPlayer.seek(startPosition ?? Duration.zero, index: targetIndex);
        }
        await _audioPlayer.play();
      } catch (e) {
        debugPrint('Error preparing background player for video: $e');
      } finally {
        isLoading.value = false;
      }

      final videoQueue = queue.value.where((f) => f.isVideo).toList();
      navigateToVideo(videoQueue.isNotEmpty ? videoQueue : [track], track);
      return;
    }

    // Android file-accessibility check (quick run)
    if (Platform.isAndroid) {
      final file = File(track.path);
      if (!await file.exists()) {
        scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
          content: Text('File does not exist: ${track.title}'),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }
    }

    isLoading.value = true;
    try {
      if (queueChanged || _playlist == null) {
        await _updatePlaylist(targetIndex, initialPosition: startPosition, includeVideo: false);
      } else {
        await _audioPlayer.seek(startPosition ?? Duration.zero, index: targetIndex);
      }
      
      // Apply correct boosted/regular volume levels
      await setVolumeScale(volumeScale.value);
      await _audioPlayer.setSpeed(playbackSpeed.value);

      // Play optimistically
      await _audioPlayer.play();
      isPlaying.value = true;

      // Fire-and-forget lyrics fetch after play starts
      unawaited(Future(() async {
        try {
          final lyricsBox = await Hive.openBox('lyrics_box');
          final fetched = await LyricsService.instance
              .fetchLyrics(track.title, track.artist);
          if (fetched != null) {
            await lyricsBox.put(track.path, fetched);
          }
        } catch (e) {
          debugPrint('Lyrics error: $e');
        }
      }));

    } catch (e) {
      debugPrint('Error loading audio track: $e');
      scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text('Error playing track: $e'),
        backgroundColor: Colors.redAccent,
      ));
      isPlaying.value = false;
    } finally {
      isLoading.value = false;
    }

    // Open audio player screen (guarded against duplicate pushes and background video transitions)
    if (!_audioScreenOpen && !forceAudio) {
      _audioScreenOpen = true;
      final route = PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AudioPlayerScreen(),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
          final tween =
              Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                  .chain(CurveTween(
                      curve: Curves.fastLinearToSlowEaseIn));
          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      );
      final nav = navigatorKey.currentState;
      if (nav != null) {
        nav.push(route).then((_) => _audioScreenOpen = false);
      } else {
        _audioScreenOpen = false;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ENQUEUE ITEMS  (bulk-add without starting playback)
  // ---------------------------------------------------------------------------
  /// Appends [items] to the end of the live queue without interrupting playback.
  ///
  /// - Audio-only items are appended; videos are skipped.
  /// - Items already in the queue are skipped (dedup by path).
  /// - If there is no active queue yet, starts playback from the first item.
  /// - The underlying [ConcatenatingAudioSource] is updated atomically so the
  ///   just_audio player sees the new tracks without restarting the current one.
  Future<void> enqueueItems(List<MediaFile> items) async {
    final audioItems = items.where((f) => !f.isVideo).toList();
    if (audioItems.isEmpty) return;

    final current = List<MediaFile>.from(queue.value);
    final newItems = audioItems
        .where((f) => !current.any((t) => _isSamePath(t.path, f.path)))
        .toList();
    if (newItems.isEmpty) return;

    // Bootstrap: no queue exists yet → start fresh
    if (current.isEmpty || _playlist == null) {
      await playTrack(newItems.first, newQueue: newItems);
      return;
    }

    // Build audio sources for the new items
    final List<AudioSource> sources = [];
    for (final track in newItems) {
      final file = File(track.path);
      if (!await file.exists()) continue;

      Uri? artUri;
      if (track.albumArtPath != null &&
          track.albumArtPath!.isNotEmpty) {
        try {
          final artFile = File(track.albumArtPath!);
          if (artFile.existsSync()) {
            artUri = Uri.file(track.albumArtPath!);
          }
        } catch (_) {}
      }

      sources.add(AudioSource.uri(
        Uri.file(track.path),
        tag: MediaItem(
          id: track.path,
          title: track.title,
          artist: track.artist,
          album: track.album,
          artUri: artUri,
        ),
      ));
    }

    if (sources.isNotEmpty) {
      // Append to the live ConcatenatingAudioSource – no seek, no restart
      await _playlist!.addAll(sources);
    }

    // Keep the queue notifier in sync
    queue.value = [...current, ...newItems];
  }

  // ---------------------------------------------------------------------------
  // STANDARD CONTROLS
  // ---------------------------------------------------------------------------
  void seek(Duration pos) {
    if (isPlayingVideoOnScreen && activeVideoController != null) {
      activeVideoController!.seekTo(pos);
      _audioPlayer.seek(pos);
    } else {
      _audioPlayer.seek(pos);
    }
  }

  void seekRelative(Duration offset) {
    final newPos = position.value + offset;
    final target = newPos < Duration.zero
        ? Duration.zero
        : (newPos > duration.value ? duration.value : newPos);
    seek(target);
  }

  void skipForward5() => seekRelative(const Duration(seconds: 5));
  void skipBackward5() => seekRelative(const Duration(seconds: -5));

  void togglePlay() {
    if (isPlayingVideoOnScreen && activeVideoController != null) {
      if (activeVideoController!.isPlaying() == true) {
        activeVideoController!.pause();
        _audioPlayer.pause();
      } else {
        activeVideoController!.play();
        _audioPlayer.play();
      }
    } else {
      if (_audioPlayer.playing) {
        _audioPlayer.pause();
      } else {
        _audioPlayer.play();
      }
    }
  }

  void next() {
    if (isPlayingVideoOnScreen && onVideoNext != null) {
      onVideoNext!();
      return;
    }
    if (queue.value.isEmpty) return;
    _playIndex((queueIndex.value + 1) % queue.value.length);
  }

  void previous() {
    if (isPlayingVideoOnScreen && onVideoPrevious != null) {
      onVideoPrevious!();
      return;
    }
    if (queue.value.isEmpty) return;
    int newIdx = queueIndex.value - 1;
    if (newIdx < 0) newIdx = queue.value.length - 1;
    _playIndex(newIdx);
  }

  void toggleShuffle() {
    isShuffle.value = !isShuffle.value;
    if (isShuffle.value) {
      if (queueIndex.value < 0 || queueIndex.value >= queue.value.length) {
        return;
      }
      _originalQueue = List<MediaFile>.from(queue.value);
      final current = queue.value[queueIndex.value];
      final shuffled = List<MediaFile>.from(queue.value)..shuffle();
      final currentIdx =
          shuffled.indexWhere((t) => _isSamePath(t.path, current.path));
      if (currentIdx != -1) {
        shuffled.removeAt(currentIdx);
        shuffled.insert(queueIndex.value, current);
      }
      queue.value = shuffled;
    } else {
      queue.value = List<MediaFile>.from(_originalQueue);
    }
  }

  void toggleRepeat() {
    switch (repeatMode.value) {
      case RepeatMode.off:
        repeatMode.value = RepeatMode.all;
        _audioPlayer.setLoopMode(LoopMode.all);
        break;
      case RepeatMode.all:
        repeatMode.value = RepeatMode.one;
        _audioPlayer.setLoopMode(LoopMode.one);
        break;
      case RepeatMode.one:
        repeatMode.value = RepeatMode.off;
        _audioPlayer.setLoopMode(LoopMode.off);
        break;
    }
  }

  void setSpeed(double speed) {
    playbackSpeed.value = speed;
    _audioPlayer.setSpeed(speed);
  }

  void setSleepTimer(int seconds) {
    _sleepTimer?.cancel();
    if (seconds <= 0) {
      sleepSecondsRemaining.value = 0;
      return;
    }
    sleepSecondsRemaining.value = seconds;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (sleepSecondsRemaining.value <= 1) {
        timer.cancel();
        _audioPlayer.pause();
        sleepSecondsRemaining.value = 0;
      } else {
        sleepSecondsRemaining.value -= 1;
      }
    });
  }

  void dismissMiniPlayer() {
    _audioPlayer.pause();
    currentTrack.value = null;
  }

  Future<void> playAll(List<MediaFile> tracks,
      {bool shuffle = false}) async {
    _originalQueue = List<MediaFile>.from(tracks);
    queue.value = List<MediaFile>.from(tracks);
    if (shuffle) queue.value.shuffle();
    if (queue.value.isNotEmpty) {
      await playTrack(queue.value.first, newQueue: queue.value);
    }
  }

  // ---------------------------------------------------------------------------
  // VOLUME & PLAYLIST HELPERS
  // ---------------------------------------------------------------------------
  Future<void> setMaxVolume() async {
    await _audioPlayer.setVolume(1.0);
  }

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await playTrack(queue.value[index], newQueue: queue.value);
  }

  Future<void> _updatePlaylist(int startIndex, {Duration? initialPosition, bool includeVideo = false}) async {
    final List<MediaFile> filteredQueue = includeVideo
        ? queue.value
        : queue.value.where((f) => !f.isVideo).toList();

    int targetIndex = 0;
    if (startIndex >= 0 && startIndex < queue.value.length) {
      final targetTrack = queue.value[startIndex];
      targetIndex = filteredQueue.indexWhere((t) => _isSamePath(t.path, targetTrack.path));
      if (targetIndex == -1) targetIndex = 0;
    }

    if (filteredQueue.isEmpty) {
      _playlist = null;
      await _audioPlayer.stop();
      return;
    }

    final targetTrack = filteredQueue[targetIndex];

    AudioSource buildSource(MediaFile track) {
      Uri? artUri;
      if (track.albumArtPath != null && track.albumArtPath!.isNotEmpty) {
        final path = track.albumArtPath!;
        bool exists = _artExistsCache[path] ?? false;
        if (!_artExistsCache.containsKey(path)) {
          exists = File(path).existsSync();
          _artExistsCache[path] = exists;
        }
        if (exists) {
          artUri = Uri.file(path);
        }
      }
      // Note: skip video thumbnail generation during background audio update to prevent blocking startup delay.
      return AudioSource.uri(
        Uri.file(track.path),
        tag: MediaItem(
          id: track.path,
          title: track.title,
          artist: track.artist,
          album: track.album,
          artUri: artUri,
        ),
      );
    }

    final targetSource = buildSource(targetTrack);
    _playlist = ConcatenatingAudioSource(children: [targetSource]);

    await _audioPlayer.setAudioSource(_playlist!,
        initialIndex: 0, initialPosition: initialPosition);

    unawaited(Future(() async {
      try {
        final List<AudioSource> precedingSources = [];
        for (int i = 0; i < targetIndex; i++) {
          precedingSources.add(buildSource(filteredQueue[i]));
        }

        final List<AudioSource> followingSources = [];
        for (int i = targetIndex + 1; i < filteredQueue.length; i++) {
          followingSources.add(buildSource(filteredQueue[i]));
        }

        if (precedingSources.isNotEmpty) {
          await _playlist!.insertAll(0, precedingSources);
        }
        if (followingSources.isNotEmpty) {
          await _playlist!.addAll(followingSources);
        }
      } catch (e) {
        debugPrint('Error asynchronously rebuilding background playlist queue: $e');
      }
    }));
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------
  void dispose() {
    _sleepTimer?.cancel();
    _heartbeatTimer?.cancel();
    _interruptionSubscription?.cancel();
    _playbackEventSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _currentIndexSubscription?.cancel();
    _audioPlayer.dispose();
    currentTrack.dispose();
    isPlaying.dispose();
    position.dispose();
    duration.dispose();
    queue.dispose();
    queueIndex.dispose();
    isShuffle.dispose();
    repeatMode.dispose();
    sleepSecondsRemaining.dispose();
    playbackSpeed.dispose();
    volumeScale.dispose();
    isLoading.dispose();
  }
}