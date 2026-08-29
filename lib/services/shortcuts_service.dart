import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'playback_service.dart';
import 'media_scanner.dart';

class ShortcutItem {
  final String action;
  final String keys;
  final String category;
  final String? description;

  const ShortcutItem({
    required this.action,
    required this.keys,
    required this.category,
    this.description,
  });
}

class PulseShortcuts {
  static const List<ShortcutItem> desktopShortcuts = [
    // Playback Controls
    ShortcutItem(action: 'Play / Pause', keys: 'Space', category: 'Playback', description: 'Toggle video or music playback'),
    ShortcutItem(action: 'Next Track', keys: 'N', category: 'Playback', description: 'Skip to next item in playlist'),
    ShortcutItem(action: 'Previous Track', keys: 'P', category: 'Playback', description: 'Return to previous track'),
    ShortcutItem(action: 'Speed Up (+0.25x)', keys: ']', category: 'Playback', description: 'Increase playback speed rate'),
    ShortcutItem(action: 'Slow Down (-0.25x)', keys: '[', category: 'Playback', description: 'Decrease playback speed rate'),
    ShortcutItem(action: 'Normal Speed (1.0x)', keys: '=', category: 'Playback', description: 'Reset playback speed to 1.0x'),
    ShortcutItem(action: 'A-B Loop Repeat', keys: 'L', category: 'Playback', description: 'Set loop start, end, and toggle repeating segment'),

    // Seeking & Navigation
    ShortcutItem(action: 'Seek Forward 5s', keys: '→', category: 'Seeking', description: 'Jump forward 5 seconds'),
    ShortcutItem(action: 'Seek Backward 5s', keys: '←', category: 'Seeking', description: 'Jump backward 5 seconds'),
    ShortcutItem(action: 'Seek Forward 30s', keys: 'Ctrl + →', category: 'Seeking', description: 'Large jump forward 30 seconds'),
    ShortcutItem(action: 'Seek Backward 30s', keys: 'Ctrl + ←', category: 'Seeking', description: 'Large jump backward 30 seconds'),
    ShortcutItem(action: 'Jump to Start', keys: 'Home', category: 'Seeking', description: 'Restart media from 00:00'),
    ShortcutItem(action: 'Jump to End', keys: 'End', category: 'Seeking', description: 'Jump to the end of media'),

    // Audio & Volume
    ShortcutItem(action: 'Volume Up (+5%)', keys: '↑', category: 'Audio', description: 'Increase audio output level'),
    ShortcutItem(action: 'Volume Down (-5%)', keys: '↓', category: 'Audio', description: 'Decrease audio output level'),
    ShortcutItem(action: 'Toggle Mute', keys: 'M', category: 'Audio', description: 'Silence audio output completely'),
    ShortcutItem(action: 'Cycle Audio Track', keys: 'B', category: 'Audio', description: 'Switch between multi-language audio streams'),

    // Subtitles
    ShortcutItem(action: 'Cycle Subtitles', keys: 'V', category: 'Subtitles', description: 'Toggle / switch available subtitle tracks'),
    ShortcutItem(action: 'Subtitle Delay (+50ms)', keys: 'H', category: 'Subtitles', description: 'Delay subtitle timing forward'),
    ShortcutItem(action: 'Subtitle Advance (-50ms)', keys: 'G', category: 'Subtitles', description: 'Advance subtitle timing backward'),
    ShortcutItem(action: 'Reset Subtitle Sync', keys: 'J', category: 'Subtitles', description: 'Reset subtitle sync timing to 0ms'),

    // Video & Display
    ShortcutItem(action: 'Toggle Fullscreen', keys: 'F', category: 'Video', description: 'Enter or exit fullscreen video mode'),
    ShortcutItem(action: 'Cycle Aspect Ratio', keys: 'A', category: 'Video', description: 'Switch between Fit, Fill, Stretch, and 16:9'),
    ShortcutItem(action: 'Rotate Video (90°)', keys: 'R', category: 'Video', description: 'Rotate video 90 degrees clockwise'),
    ShortcutItem(action: 'Take Snapshot', keys: 'S', category: 'Video', description: 'Capture frame-accurate image snapshot'),
    ShortcutItem(action: 'Media Stats / Codec', keys: 'Ctrl + J', category: 'Video', description: 'Show video resolution, bitrate, & codec info'),

    // System & Open
    ShortcutItem(action: 'Open File', keys: 'Ctrl + O', category: 'System', description: 'Browse and open media file from disk'),
    ShortcutItem(action: 'Open Network Stream', keys: 'Ctrl + N', category: 'System', description: 'Stream video or audio from URL (HLS / RTSP)'),
    ShortcutItem(action: 'Shortcuts Guide', keys: '?', category: 'System', description: 'Display all keyboard shortcuts & controls'),
  ];

  static const List<ShortcutItem> mobileGestures = [
    ShortcutItem(action: 'Swipe Left / Right', keys: 'Center Drag', category: 'Playback Gestures', description: 'Smooth seek forward / backward'),
    ShortcutItem(action: 'Double Tap Right', keys: '2x Tap Right', category: 'Playback Gestures', description: 'Jump +10 seconds forward'),
    ShortcutItem(action: 'Double Tap Left', keys: '2x Tap Left', category: 'Playback Gestures', description: 'Jump -10 seconds backward'),
    ShortcutItem(action: 'Long Press', keys: 'Hold Screen', category: 'Playback Gestures', description: 'Turbo 2x speed playback while held'),
    ShortcutItem(action: 'Left Edge Swipe', keys: 'Vertical Drag Left', category: 'Controls', description: 'Adjust screen brightness smoothly'),
    ShortcutItem(action: 'Right Edge Swipe', keys: 'Vertical Drag Right', category: 'Controls', description: 'Adjust volume smoothly'),
    ShortcutItem(action: 'Pinch to Zoom', keys: '2-Finger Pinch', category: 'Video Scale', description: 'Freely zoom and pan video frame'),
  ];

  /// Handles desktop keyboard events
  static void handleKeyEvent(
    KeyEvent event,
    BuildContext context, {
    VoidCallback? onOpenNetworkStream,
    VoidCallback? onOpenFile,
    VoidCallback? onToggleSubtitles,
    VoidCallback? onCycleAudioTrack,
    VoidCallback? onToggleFullscreen,
    VoidCallback? onCycleAspectRatio,
    VoidCallback? onRotateVideo,
    VoidCallback? onTakeSnapshot,
    VoidCallback? onToggleStats,
  }) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;
    final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;

    // Space: Play/Pause
    if (key == LogicalKeyboardKey.space) {
      PlaybackService.instance.togglePlayPause();
    }
    // Arrows: Seeking
    else if (key == LogicalKeyboardKey.arrowRight) {
      final pos = PlaybackService.instance.position.value;
      final step = isCtrl ? const Duration(seconds: 30) : const Duration(seconds: 5);
      PlaybackService.instance.seek(pos + step);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      final pos = PlaybackService.instance.position.value;
      final step = isCtrl ? const Duration(seconds: 30) : const Duration(seconds: 5);
      final newPos = pos - step;
      PlaybackService.instance.seek(newPos < Duration.zero ? Duration.zero : newPos);
    }
    // Up / Down: Volume
    else if (key == LogicalKeyboardKey.arrowUp) {
      final currentVol = PlaybackService.instance.volumeScale.value;
      PlaybackService.instance.setVolumeScale((currentVol + 0.05).clamp(0.0, 1.0));
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final currentVol = PlaybackService.instance.volumeScale.value;
      PlaybackService.instance.setVolumeScale((currentVol - 0.05).clamp(0.0, 1.0));
    }
    // M: Mute
    else if (key == LogicalKeyboardKey.keyM) {
      final currentVol = PlaybackService.instance.volumeScale.value;
      if (currentVol > 0.0) {
        PlaybackService.instance.setVolumeScale(0.0);
      } else {
        PlaybackService.instance.setVolumeScale(1.0);
      }
    }
    // N / P: Next / Previous
    else if (key == LogicalKeyboardKey.keyN && !isCtrl) {
      PlaybackService.instance.playNext();
    } else if (key == LogicalKeyboardKey.keyP && !isCtrl) {
      PlaybackService.instance.playPrevious();
    }
    // [ / ]: Speed
    else if (key == LogicalKeyboardKey.bracketRight) {
      final speed = PlaybackService.instance.player.speed;
      PlaybackService.instance.setPlaybackSpeed((speed + 0.25).clamp(0.25, 3.0));
    } else if (key == LogicalKeyboardKey.bracketLeft) {
      final speed = PlaybackService.instance.player.speed;
      PlaybackService.instance.setPlaybackSpeed((speed - 0.25).clamp(0.25, 3.0));
    } else if (key == LogicalKeyboardKey.equal) {
      PlaybackService.instance.setPlaybackSpeed(1.0);
    }
    // B: Audio track switch
    else if (key == LogicalKeyboardKey.keyB && !isCtrl) {
      if (onCycleAudioTrack != null) onCycleAudioTrack();
    }
    // V: Subtitles switch
    else if (key == LogicalKeyboardKey.keyV && !isCtrl) {
      if (onToggleSubtitles != null) onToggleSubtitles();
    }
    // F: Fullscreen
    else if (key == LogicalKeyboardKey.keyF && !isCtrl) {
      if (onToggleFullscreen != null) onToggleFullscreen();
    }
    // A: Aspect Ratio
    else if (key == LogicalKeyboardKey.keyA && !isCtrl) {
      if (onCycleAspectRatio != null) onCycleAspectRatio();
    }
    // R: Rotate
    else if (key == LogicalKeyboardKey.keyR && !isCtrl) {
      if (onRotateVideo != null) onRotateVideo();
    }
    // S: Screenshot Snapshot
    else if (key == LogicalKeyboardKey.keyS && !isCtrl) {
      if (onTakeSnapshot != null) onTakeSnapshot();
    }
    // Ctrl + J: Media Stats
    else if (isCtrl && key == LogicalKeyboardKey.keyJ) {
      if (onToggleStats != null) onToggleStats();
    }
    // Ctrl + N: Network Stream
    else if (isCtrl && key == LogicalKeyboardKey.keyN) {
      if (onOpenNetworkStream != null) onOpenNetworkStream();
    }
    // Ctrl + O: Open file
    else if (isCtrl && key == LogicalKeyboardKey.keyO) {
      if (onOpenFile != null) {
        onOpenFile();
      } else {
        MediaScanner.instance.pickAndAddCustomFolder();
      }
    }
  }
}
