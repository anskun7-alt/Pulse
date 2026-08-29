import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_session/audio_session.dart';
import '../models/media_file.dart';
import 'playlist_service.dart';
import 'color_service.dart';
import '../app.dart';
import '../players/audio_player_screen.dart';
import '../players/video_player_screen.dart';

/// PlaybackController is the single source of truth for both UI layers and the
/// background audio service. It mirrors the previous PlaybackService but adds
/// periodic state persistence, lifecycle handling, and notification dismissal
/// logic required for MX‑Player‑like background behaviour.
class PlaybackController {
  // Singleton instance
  static final PlaybackController instance = PlaybackController._internal();
  PlaybackController._internal();

  // Audio player used for background audio
  late final AudioPlayer _audioPlayer;

  // Notifiers for UI consumption
  final ValueNotifier<MediaFile?> currentTrack = ValueNotifier<MediaFile?>(null);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<List<MediaFile>> queue = ValueNotifier<List<MediaFile>>([]);
  final ValueNotifier<int> queueIndex = ValueNotifier<int>(-1);
  final ValueNotifier<bool> isShuffle = ValueNotifier<bool>(false);
  final ValueNotifier<RepeatMode> repeatMode = ValueNotifier<RepeatMode>(RepeatMode.off);
  final ValueNotifier<double> playbackSpeed = ValueNotifier<double>(1.0);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  // Internal state
  bool _audioScreenOpen = false;
  Timer? _positionSaveTimer;
  Timer? _sleepTimer;
  final ValueNotifier<int> sleepSecondsRemaining = ValueNotifier<int>(0);
  ConcatenatingAudioSource? _playlist;
  List<MediaFile> _originalQueue = [];
  bool _wasPlayingBeforeInterruption = false;

  // ---------------------------------------------------------------------------
  // INITIALISATION
  // ---------------------------------------------------------------------------
  Future<void> init() async {
    _audioPlayer = AudioPlayer();
    await _audioPlayer.setVolume(1.0);
    await _requestStoragePermission();
    await _configureAudioSession();
    _listenToPlayerEvents();
    _startPositionPersistence();
  }

  Future<void> _requestStoragePermission() async {
    try {
      await Permission.storage.request();
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    } catch (_) {}
  }

  Future<void> _configureAudioSession() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
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
        _listenToInterruptions(session);
      } catch (_) {}
    }
  }

  void _listenToInterruptions(AudioSession session) {
    _interruptionSubscription = session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        if (event.type == AudioInterruptionType.pause && _audioPlayer.playing) {
          _wasPlayingBeforeInterruption = true;
          await _audioPlayer.pause();
        } else if (event.type == AudioInterruptionType.duck) {
          await _audioPlayer.setVolume(0.2);
        }
      } else {
        if (event.type == AudioInterruptionType.pause && _wasPlayingBeforeInterruption) {
          _wasPlayingBeforeInterruption = false;
          await _audioPlayer.play();
        } else if (event.type == AudioInterruptionType.duck) {
          await _audioPlayer.setVolume(1.0);
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // PLAYER STATE LISTENERS
  // ---------------------------------------------------------------------------
  late final StreamSubscription _interruptionSubscription;
  late final StreamSubscription _playerStateSubscription;
  late final StreamSubscription _positionSubscription;
  late final StreamSubscription _durationSubscription;
  late final StreamSubscription _currentIndexSubscription;

  void _listenToPlayerEvents() {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      isPlaying.value = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _handleCompletion();
      }
    });

    _positionSubscription = _audioPlayer.positionStream.listen((pos) {
      position.value = pos;
    });

    _durationSubscription = _audioPlayer.durationStream.listen((dur) {
      if (dur != null) duration.value = dur;
    });

    _currentIndexSubscription = _audioPlayer.currentIndexStream.listen((index) {
      if (index != null && _playlist != null && index < _playlist!.children.length) {
        final source = _playlist!.children[index] as UriAudioSource;
        final media = source.tag as MediaItem;
        final matched = queue.value.indexWhere((t) => t.path == media.id);
        if (matched != -1) {
          queueIndex.value = matched;
          currentTrack.value = queue.value[matched];
          _updateColorFromArt(currentTrack.value);
        }
      }
    });
  }

  Future<void> _updateColorFromArt(MediaFile? track) async {
    if (track == null) return;
    try {
      if (track.albumArtPath != null && File(track.albumArtPath!).existsSync()) {
        await ColorService.instance.updateFromImage(FileImage(File(track.albumArtPath!)));
      } else {
        ColorService.instance.reset();
      }
    } catch (_) {}
  }

  void _handleCompletion() {
    switch (repeatMode.value) {
      case RepeatMode.off:
        isPlaying.value = false;
        _audioPlayer.pause();
        _audioPlayer.seek(Duration.zero, index: 0);
        break;
      case RepeatMode.all:
        break;
      case RepeatMode.one:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // PLAYLIST MANAGEMENT
  // ---------------------------------------------------------------------------
  Future<void> _updatePlaylist(int targetIndexInQueue) async {
    final List<AudioSource> children = [];
    for (final track in queue.value) {
      if (track.isVideo) continue;
      final file = File(track.path);
      if (!await file.exists()) continue;
      final artUri = await _resolveArtUri(track.albumArtPath);
      children.add(AudioSource.uri(
        Uri.file(track.path),
        tag: MediaItem(
          id: track.path,
          album: track.album,
          title: track.title,
          artist: track.artist,
          artUri: artUri,
          duration: track.duration,
        ),
      ));
    }
    if (children.isEmpty) return;
    _playlist = ConcatenatingAudioSource(children: children);
    int initialIndex = 0;
    if (targetIndexInQueue >= 0 && targetIndexInQueue < queue.value.length) {
      final targetPath = queue.value[targetIndexInQueue].path;
      final idx = children.indexWhere((src) => (src as UriAudioSource).tag.id == targetPath);
      if (idx != -1) initialIndex = idx;
    }
    await _audioPlayer.setAudioSource(_playlist!, initialIndex: initialIndex, initialPosition: Duration.zero);
  }

  Future<Uri?> _resolveArtUri(String? artPath) async {
    if (artPath == null || artPath.isEmpty) return null;
    try {
      final file = File(artPath);
      if (await file.exists()) {
        if (Platform.isAndroid) {
          final tempDir = Directory.systemTemp;
          final fileName = artPath.split(Platform.pathSeparator).last;
          final tempFile = File('${tempDir.path}/$fileName');
          if (!await tempFile.exists()) await file.copy(tempFile.path);
          return Uri.file(tempFile.path);
        }
        return Uri.file(artPath);
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------------------
  Future<void> playTrack(MediaFile track, {List<MediaFile>? newQueue}) async {
    bool queueChanged = false;
    int targetIdx = 0;
    if (newQueue != null) {
      queueChanged = true;
      if (isShuffle.value) {
        _originalQueue = List<MediaFile>.from(newQueue);
        final shuffled = List<MediaFile>.from(newQueue)..removeWhere((t) => t.path == track.path);
        shuffled.shuffle();
        shuffled.insert(0, track);
        queue.value = shuffled;
        targetIdx = 0;
      } else {
        _originalQueue = List<MediaFile>.from(newQueue);
        queue.value = newQueue;
        targetIdx = newQueue.indexWhere((t) => t.path == track.path);
      }
    } else if (!queue.value.any((t) => t.path == track.path)) {
      queueChanged = true;
      queue.value = [track];
      targetIdx = 0;
    } else {
      targetIdx = queue.value.indexWhere((t) => t.path == track.path);
    }

    await PlaylistService.instance.logPlay(track.path);

    if (track.isVideo) {
      if (_audioPlayer.playing) await _audioPlayer.pause();
      final videoQueue = queue.value.where((f) => f.isVideo).toList();
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            file: track,
            playlist: videoQueue.isNotEmpty ? videoQueue : [track],
          ),
        ),
      );
      return;
    }

    isLoading.value = true;
    try {
      if (queueChanged || _playlist == null) {
        await _updatePlaylist(targetIdx);
      } else {
        await _audioPlayer.seek(Duration.zero, index: targetIdx);
      }
      duration.value = _audioPlayer.duration ?? Duration.zero;
      await _audioPlayer.setSpeed(playbackSpeed.value);
      await _audioPlayer.play();
      isPlaying.value = true;
    } catch (_) {
      isPlaying.value = false;
    } finally {
      isLoading.value = false;
    }

    _audioScreenOpen = true;
  }

  // ---------------------------------------------------------------------------
  // BULK ENQUEUE (new – used by PlaylistManager and ActionToolbar)
  // ---------------------------------------------------------------------------

  /// Appends [items] to the end of the live queue without starting playback.
  ///
  /// - Audio files are appended to [_playlist] via [ConcatenatingAudioSource].
  /// - Video files are ignored (the video player owns its own queue).
  /// - Items already present in the queue are skipped (dedup by path).
  ///
  /// If there is no active queue yet, the items are set as the new queue and
  /// playback begins from the first item.
  Future<void> enqueueItems(List<MediaFile> items) async {
    final audioItems = items.where((f) => !f.isVideo).toList();
    if (audioItems.isEmpty) return;

    final current = List<MediaFile>.from(queue.value);
    final newItems = audioItems.where((f) => !current.any((t) => t.path == f.path)).toList();
    if (newItems.isEmpty) return;

    // No active queue — start fresh
    if (current.isEmpty || _playlist == null) {
      await playTrack(newItems.first, newQueue: newItems);
      return;
    }

    // Append to the existing ConcatenatingAudioSource
    final List<AudioSource> sources = [];
    for (final track in newItems) {
      final file = File(track.path);
      if (!await file.exists()) continue;
      final artUri = await _resolveArtUri(track.albumArtPath);
      sources.add(AudioSource.uri(
        Uri.file(track.path),
        tag: MediaItem(
          id: track.path,
          album: track.album,
          title: track.title,
          artist: track.artist,
          artUri: artUri,
          duration: track.duration,
        ),
      ));
    }
    if (sources.isNotEmpty) {
      await _playlist!.addAll(sources);
    }

    // Keep the queue notifier in sync
    queue.value = [...current, ...newItems];
  }

  // ---------------------------------------------------------------------------
  // STANDARD CONTROLS
  // ---------------------------------------------------------------------------
  void seek(Duration pos) => _audioPlayer.seek(pos);

  void seekRelative(Duration offset) {
    final newPos = position.value + offset;
    final target = newPos < Duration.zero
        ? Duration.zero
        : (newPos > duration.value ? duration.value : newPos);
    _audioPlayer.seek(target);
  }

  void togglePlay() {
    if (isPlaying.value) {
      _audioPlayer.pause();
    } else {
      if (currentTrack.value != null) _audioPlayer.play();
    }
  }

  void setSpeed(double speed) {
    playbackSpeed.value = speed;
    _audioPlayer.setSpeed(speed);
  }

  void next() {
    if (queue.value.isEmpty) return;
    int nextIdx = queueIndex.value + 1;
    if (nextIdx >= queue.value.length) nextIdx = 0;
    _audioPlayer.seek(Duration.zero, index: nextIdx);
  }

  void previous() {
    if (queue.value.isEmpty) return;
    int prevIdx = queueIndex.value - 1;
    if (prevIdx < 0) prevIdx = queue.value.length - 1;
    _audioPlayer.seek(Duration.zero, index: prevIdx);
  }

  void toggleShuffle() {
    isShuffle.value = !isShuffle.value;
    if (isShuffle.value) {
      _originalQueue = List<MediaFile>.from(queue.value);
      final current = currentTrack.value;
      if (current != null) {
        final list = List<MediaFile>.from(queue.value)..removeWhere((t) => t.path == current.path);
        list.shuffle();
        list.insert(0, current);
        queue.value = list;
        queueIndex.value = 0;
        _updatePlaylist(0);
      }
    } else {
      if (_originalQueue.isNotEmpty) {
        queue.value = List<MediaFile>.from(_originalQueue);
        final current = currentTrack.value;
        if (current != null) {
          queueIndex.value = queue.value.indexWhere((t) => t.path == current.path);
          _updatePlaylist(queueIndex.value);
        }
      }
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

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    if (minutes == 0) {
      sleepSecondsRemaining.value = 0;
      return;
    }
    sleepSecondsRemaining.value = minutes * 60;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (sleepSecondsRemaining.value > 0) {
        sleepSecondsRemaining.value--;
        if (sleepSecondsRemaining.value == 0) {
          _audioPlayer.pause();
          t.cancel();
        }
      } else {
        t.cancel();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // BACKGROUND STATE PERSISTENCE
  // ---------------------------------------------------------------------------
  void _startPositionPersistence() {
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final box = Hive.box('settings_box');
      if (currentTrack.value != null) {
        box.put('last_position', position.value.inMilliseconds);
        box.put('last_track_path', currentTrack.value!.path);
      }
    });
  }

  Future<void> restoreLastState() async {
    final box = Hive.box('settings_box');
    final path = box.get('last_track_path') as String?;
    final ms = box.get('last_position') as int?;
    if (path != null && ms != null) {
      final track = await _findTrackByPath(path);
      if (track != null) {
        await playTrack(track);
        seek(Duration(milliseconds: ms));
      }
    }
  }

  Future<MediaFile?> _findTrackByPath(String path) async {
    for (final t in queue.value) {
      if (t.path == path) return t;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATION DISMISS HANDLING
  // ---------------------------------------------------------------------------
  Future<void> handleNotificationDismissed() async {
    await stop();
    final box = Hive.box('settings_box');
    await box.delete('last_position');
    await box.delete('last_track_path');
  }

  // ---------------------------------------------------------------------------
  // STOP / CLEANUP
  // ---------------------------------------------------------------------------
  Future<void> stop() async {
    await _audioPlayer.stop();
    currentTrack.value = null;
    isPlaying.value = false;
    _audioScreenOpen = false;
    ColorService.instance.reset();
    _positionSaveTimer?.cancel();
  }

  void dispose() {
    _sleepTimer?.cancel();
    _positionSaveTimer?.cancel();
    _interruptionSubscription.cancel();
    _playerStateSubscription.cancel();
    _positionSubscription.cancel();
    _durationSubscription.cancel();
    _currentIndexSubscription.cancel();
    _audioPlayer.dispose();
    currentTrack.dispose();
    isPlaying.dispose();
    position.dispose();
    duration.dispose();
    queue.dispose();
    queueIndex.dispose();
    isShuffle.dispose();
    repeatMode.dispose();
    playbackSpeed.dispose();
    isLoading.dispose();
  }
}

enum RepeatMode { off, all, one }