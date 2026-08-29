import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:just_audio/just_audio.dart';

enum AudioFocusOwner { none, music, video }

/// Central Audio Focus Coordinator preventing hardware audio sink collisions
/// between ExoPlayer (BetterPlayer) and JustAudio on Android/iOS/Desktop.
class AudioFocusController {
  static final AudioFocusController instance = AudioFocusController._internal();
  AudioFocusController._internal();

  AudioFocusOwner _currentOwner = AudioFocusOwner.none;
  AudioFocusOwner get currentOwner => _currentOwner;

  BetterPlayerController? _activeVideoController;
  AudioPlayer? _activeAudioPlayer;

  void registerPlayers({
    AudioPlayer? audioPlayer,
    BetterPlayerController? videoController,
  }) {
    if (audioPlayer != null) _activeAudioPlayer = audioPlayer;
    if (videoController != null) _activeVideoController = videoController;
  }

  void updateActiveVideoController(BetterPlayerController? controller) {
    _activeVideoController = controller;
  }

  /// Prepare audio pipeline for Music Playback (acquiring music focus).
  Future<void> requestMusicFocus() async {
    debugPrint('[AudioFocus] Requesting focus for MUSIC (current: $_currentOwner)');

    // Cleanly silence / pause active video sink to release native audio track
    if (_activeVideoController != null) {
      try {
        if (_activeVideoController!.isPlaying() == true) {
          debugPrint('[AudioFocus] Pausing active video player to transfer audio focus.');
          await _activeVideoController!.pause();
        }
        await _activeVideoController!.setVolume(0.0);
      } catch (e) {
        debugPrint('[AudioFocus] Warning while silencing video controller: $e');
      }
    }

    _currentOwner = AudioFocusOwner.music;
  }

  /// Prepare audio pipeline for Video Playback (acquiring video focus).
  Future<void> requestVideoFocus() async {
    debugPrint('[AudioFocus] Requesting focus for VIDEO (current: $_currentOwner)');

    // Cleanly pause JustAudio player to release native audio sink
    if (_activeAudioPlayer != null) {
      try {
        if (_activeAudioPlayer!.playing) {
          debugPrint('[AudioFocus] Pausing JustAudio player to transfer audio focus.');
          await _activeAudioPlayer!.pause();
        }
      } catch (e) {
        debugPrint('[AudioFocus] Warning while pausing JustAudio player: $e');
      }
    }

    _currentOwner = AudioFocusOwner.video;
  }

  /// Execute an audio operation with retry logic for ERROR_DEAD_OBJECT / uninitialized audio sink recovery.
  Future<T?> executeWithRecovery<T>({
    required Future<T> Function() operation,
    int maxRetries = 2,
    Duration delay = const Duration(milliseconds: 300),
    String opName = 'AudioOperation',
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      attempts++;
      try {
        return await operation();
      } catch (e) {
        debugPrint('[AudioFocus] $opName failed on attempt $attempts/$maxRetries: $e');
        if (attempts >= maxRetries) {
          rethrow;
        }
        await Future.delayed(delay * attempts);
      }
    }
    return null;
  }

  /// Reset audio focus when all playback ceases.
  void releaseFocus() {
    debugPrint('[AudioFocus] Releasing all audio focus.');
    _currentOwner = AudioFocusOwner.none;
  }
}
